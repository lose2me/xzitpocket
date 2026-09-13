import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'talker.dart';
import 'dio_factory.dart';

class PowerQueryException implements Exception {
  final String message;

  const PowerQueryException(this.message);

  @override
  String toString() => message;
}

class PowerDailyUsage {
  final String date;
  final String usage;
  final String? isoDate;

  const PowerDailyUsage({
    required this.date,
    required this.usage,
    this.isoDate,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'usage': usage,
    if (isoDate != null) 'isoDate': isoDate,
  };

  factory PowerDailyUsage.fromJson(Map<String, dynamic> json) =>
      PowerDailyUsage(
        date: json['date'] as String,
        usage: json['usage'] as String,
        isoDate: json['isoDate'] as String?,
      );

  /// Stable date key used by sorting and charts.
  ///
  /// Older caches only contain the localized label, so keep that format as a
  /// backwards-compatible fallback while new responses persist [isoDate].
  DateTime get dateValue {
    final iso = isoDate == null ? null : DateTime.tryParse(isoDate!);
    if (iso != null) return iso;

    final isoMatch = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})')
        .firstMatch(date);
    if (isoMatch != null) {
      return DateTime(
        int.parse(isoMatch.group(1)!),
        int.parse(isoMatch.group(2)!),
        int.parse(isoMatch.group(3)!),
      );
    }

    final chineseMatch = RegExp(r'^(\d{1,2})月(\d{1,2})日').firstMatch(date);
    if (chineseMatch != null) {
      final now = DateTime.now();
      return DateTime(
        now.year,
        int.parse(chineseMatch.group(1)!),
        int.parse(chineseMatch.group(2)!),
      );
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class PowerQueryData {
  final String price;
  final String available;
  final String? monthUsage;
  final String? estDays;
  final List<PowerDailyUsage> dailyUsage;

  const PowerQueryData({
    required this.price,
    required this.available,
    this.monthUsage,
    this.estDays,
    this.dailyUsage = const [],
  });

  Map<String, dynamic> toJson() => {
    'price': price,
    'available': available,
    if (monthUsage != null) 'monthUsage': monthUsage,
    if (estDays != null) 'estDays': estDays,
    'dailyUsage': dailyUsage.map((e) => e.toJson()).toList(),
  };

  factory PowerQueryData.fromJson(Map<String, dynamic> json) => PowerQueryData(
    price: json['price'] as String,
    available: json['available'] as String,
    monthUsage: json['monthUsage'] as String?,
    estDays: json['estDays'] as String?,
    dailyUsage:
        (json['dailyUsage'] as List<dynamic>?)
            ?.map((e) => PowerDailyUsage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class PowerService {
  static const _roomDbAssetPath = 'fmd/power/room.db';
  static const _roomDbFileName = 'power_room_v1.db';
  static const _requestTimeout = Duration(seconds: 10);
  static const _estDaysMin = 7;

  static const Map<String, _EndpointConfig> _endpoints = {
    'zx': _EndpointConfig(
      url: 'http://211.87.126.94/zx',
      mode: _EndpointMode.legacy,
      timeout: _requestTimeout,
      price: '0.54',
      shouldDivideByPrice: false,
      loginPath: '/chkuser.fwps',
      consumeHistoryPath: '/consumeHistory.fwps',
    ),
    'cn': _EndpointConfig(
      url: 'http://211.87.126.94/cn',
      mode: _EndpointMode.legacy,
      timeout: _requestTimeout,
      price: '0.54',
      loginPath: '/chkuser.fwp',
      consumeHistoryPath: '/consumeHistory.fwp',
    ),
    'dxq': _EndpointConfig(
      url: 'http://211.87.126.249/dxq',
      mode: _EndpointMode.dxq,
      timeout: _requestTimeout,
      price: '0.54',
    ),
  };

  Database? _database;

  Future<bool> validateRoom(String customId) async {
    final roomId = _normalizeRoomId(customId);
    if (roomId.isEmpty) return false;
    try {
      await _getRoomByCustomId(roomId);
      return true;
    } on PowerQueryException {
      return false;
    }
  }

  Future<PowerQueryData> queryRoom(
    String customId, {
    String? startDate,
    String? endDate,
  }) async {
    final roomId = _normalizeRoomId(customId);
    if (roomId.isEmpty) {
      throw const PowerQueryException('请输入房间号');
    }

    final room = await _getRoomByCustomId(roomId);
    final endpoint = _endpoints[room.endpoint];
    if (endpoint == null) {
      throw const PowerQueryException('房间配置异常');
    }

    final jar = CookieJar();
    final dio = DioFactory.create(
      baseUrl: endpoint.url,
      cookieJar: jar,
      connectTimeout: endpoint.timeout,
      receiveTimeout: endpoint.timeout,
      bypassProxy: true,
    );
    try {
      final raw = endpoint.mode == _EndpointMode.dxq
          ? await _queryDxqRoom(
              dio,
              room,
              startDate: startDate,
              endDate: endDate,
            )
          : await _queryLegacyRoom(
              dio,
              room,
              endpoint,
              startDate: startDate,
              endDate: endDate,
            );
      var result = _buildQueryData(raw, endpoint);

      if (result.estDays == '样本不足' && startDate == null && endDate == null) {
        // The default query already covers the latest 30 days. Only fetch the
        // portion immediately before that window, otherwise the overlap would
        // bias the average daily usage used for the estimate.
        final now = DateTime.now();
        final currentStart = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30));
        final previousEnd = currentStart.subtract(const Duration(days: 1));
        final previousStart = DateTime(previousEnd.year, previousEnd.month, 1);
        List<PowerDailyUsage> extraUsage;
        if (endpoint.mode == _EndpointMode.dxq) {
          extraUsage = await _fetchDxqUsageRecords(
            dio,
            startDate: _formatIsoDate(previousStart),
            endDate: _formatIsoDate(previousEnd),
          );
        } else {
          final extraRaw = await _queryLegacyRoom(
            dio,
            room,
            endpoint,
            startDate: _formatIsoDate(previousStart),
            endDate: _formatIsoDate(previousEnd),
          );
          extraUsage =
              (extraRaw['dailyUsage'] as List<PowerDailyUsage>?) ?? const [];
        }
        final combined = [...result.dailyUsage, ...extraUsage];
        final newEst = _estimateDaysLeft(result.available, combined);
        result = PowerQueryData(
          price: result.price,
          available: result.available,
          monthUsage: result.monthUsage,
          estDays: newEst,
          dailyUsage: result.dailyUsage,
        );
      }

      return result;
    } finally {
      dio.close(force: true);
    }
  }

  Future<RoomRecord> _getRoomByCustomId(String customId) async {
    final db = await _openRoomDatabase();
    final rows = await db.query(
      'rooms',
      columns: const ['endpoint', 'roomName', 'roomID', 'pwd'],
      where: 'ID = ?',
      whereArgs: [customId],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw const PowerQueryException('无此房间号');
    }

    final row = rows.first;
    return RoomRecord(
      endpoint: row['endpoint'] as String? ?? '',
      roomName: row['roomName'] as String? ?? '',
      roomId: row['roomID'] as String? ?? '',
      password: row['pwd'] as String? ?? '',
    );
  }

  Future<Database> _openRoomDatabase() async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final databaseDir = await getDatabasesPath();
    final databasePath = path.join(databaseDir, _roomDbFileName);
    await _ensureRoomDatabaseFile(databasePath);

    final database = await openDatabase(
      databasePath,
      readOnly: true,
      singleInstance: true,
    );
    _database = database;
    return database;
  }

  Future<void> _ensureRoomDatabaseFile(String databasePath) async {
    await Directory(path.dirname(databasePath)).create(recursive: true);

    final byteData = await rootBundle.load(_roomDbAssetPath);
    final assetBytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final databaseFile = File(databasePath);
    if (await databaseFile.exists()) {
      final localBytes = await databaseFile.readAsBytes();
      if (_hashBytes(localBytes) == _hashBytes(assetBytes)) {
        return;
      }
    }

    await databaseFile.writeAsBytes(assetBytes, flush: true);
  }

  Future<Map<String, Object>> _queryLegacyRoom(
    Dio dio,
    RoomRecord room,
    _EndpointConfig endpoint, {
    String? startDate,
    String? endDate,
  }) async {
    await _loginLegacy(dio, room, endpoint);

    final range = _resolveDateRange(startDate, endDate);
    final cursor = DateTime(range.start.year, range.start.month);
    final lastMonth = DateTime(range.end.year, range.end.month);
    final dailyUsage = <PowerDailyUsage>[];
    String monthUsage = '';
    String available = '';

    // Both legacy hosts expose the same server-rendered consumeHistory page.
    // A range spanning multiple months is therefore queried once per month;
    // no JSON probe or alternate endpoint is involved.
    var month = cursor;
    while (!month.isAfter(lastMonth)) {
      final dateSuffix = _buildLegacyDateQuery(
        '${month.year}-${month.month.toString().padLeft(2, '0')}',
      );
      final consumeHtml = await _requestText(
        dio,
        'GET',
        '${endpoint.consumeHistoryPath}$dateSuffix',
      );
      final parsed = _parseLegacyConsumeHistory(
        consumeHtml,
        month.year,
        month.month,
      );
      monthUsage = parsed['monthUsage'] as String? ?? monthUsage;
      available = parsed['available'] as String? ?? available;
      final records =
          (parsed['dailyUsage'] as List<PowerDailyUsage>?) ?? const [];
      dailyUsage.addAll(
        records.where((item) => _legacyDateInRange(item.date, month, range)),
      );
      month = DateTime(month.year, month.month + 1);
    }

    _sortDailyUsage(dailyUsage);
    return {
      'monthUsage': monthUsage,
      'available': available,
      'dailyUsage': dailyUsage,
    };
  }

  String _buildLegacyDateQuery(String? startDate) {
    if (startDate == null || startDate.isEmpty) return '';
    final match = RegExp(r'(\d{4})-(\d{1,2})').firstMatch(startDate);
    if (match == null) return '';
    final year = match.group(1)!;
    final month = int.parse(match.group(2)!);
    return '?nYear=$year&nMonth=$month';
  }

  Future<void> _loginLegacy(
    Dio dio,
    RoomRecord room,
    _EndpointConfig endpoint,
  ) async {
    final loginPage = await _requestText(dio, 'GET', '/');
    final sessionMatch = RegExp(r'g_pswSession\s*=\s*(\d+)')
        .firstMatch(loginPage);
    final session = sessionMatch?.group(1);
    if (session == null) {
      throw const PowerQueryException('登录页中未找到 g_pswSession');
    }
    if (room.password.isEmpty) {
      throw const PowerQueryException('房间缺少查询密码');
    }

    final password = _md5Hex(_md5Hex('${room.password}$session'));
    final responseText = await _requestText(
      dio,
      'POST',
      endpoint.loginPath,
      data: {
        'login_type': 'accountId',
        'login_roomName': room.roomName,
        'login_roomID': room.roomId,
        'password': password,
      },
      headers: {
        'Referer': '${endpoint.url}/',
        'X-Requested-With': 'XMLHttpRequest',
      },
    );

    _parseLoginResult(responseText);
  }

  Future<Map<String, Object>> _queryDxqRoom(
    Dio dio,
    RoomRecord room, {
    String? startDate,
    String? endDate,
  }) async {
    if (room.roomId.length < 4) {
      throw const PowerQueryException('dxq 房间编码无效');
    }

    final building = room.roomId.substring(0, 2);
    final floor = room.roomId.substring(0, 4);

    // DXQ requires the ASP.NET selection postback chain. A direct WebMethod
    // request is not exposed by this endpoint, and submitting all selections
    // in one step only returns the selection page without balance data.
    final landingHtml = await _requestText(dio, 'GET', '/');
    final landingDoc = html_parser.parse(landingHtml);
    final initViewState = _getInputValue(landingDoc, '__VIEWSTATE');
    final initViewStateGen = _getInputValue(landingDoc, '__VIEWSTATEGENERATOR');

    final buildingHtml = await _postDxqForm(
      dio,
      viewState: initViewState,
      viewStateGenerator: initViewStateGen,
      building: building,
      floor: '',
      roomId: '',
    );

    final buildingDoc = html_parser.parse(buildingHtml);
    final floorHtml = await _postDxqForm(
      dio,
      viewState: _getInputValue(buildingDoc, '__VIEWSTATE'),
      viewStateGenerator: _getInputValue(buildingDoc, '__VIEWSTATEGENERATOR'),
      building: building,
      floor: floor,
      roomId: '',
    );

    final floorDoc = html_parser.parse(floorHtml);
    final resultHtml = await _postDxqForm(
      dio,
      viewState: _getInputValue(floorDoc, '__VIEWSTATE'),
      viewStateGenerator: _getInputValue(floorDoc, '__VIEWSTATEGENERATOR'),
      building: building,
      floor: floor,
      roomId: room.roomId,
      submit: true,
    );

    final dailyUsage = await _fetchDxqUsageRecords(
      dio,
      startDate: startDate,
      endDate: endDate,
    );
    talker.debug('[NET] 电费DXQ\n三步 postback 查询成功');
    return {
      'available': _parseDxqAvailable(resultHtml),
      'dailyUsage': dailyUsage,
    };
  }

  Future<List<PowerDailyUsage>> _fetchDxqUsageRecords(
    Dio dio, {
    String? startDate,
    String? endDate,
  }) async {
    final range = _resolveDateRange(startDate, endDate);
    final html = await _requestText(dio, 'GET', '/allRecord.aspx');
    final doc = html_parser.parse(html);
    final vs =
        doc.querySelector('input#__VIEWSTATE')?.attributes['value'] ?? '';
    final vsg =
        doc.querySelector('input#__VIEWSTATEGENERATOR')?.attributes['value'] ??
        '';
    final ev =
        doc.querySelector('input#__EVENTVALIDATION')?.attributes['value'] ?? '';
    if (vs.isEmpty || ev.isEmpty) {
      throw const PowerQueryException('dxq 用电记录页面结构异常');
    }

    final resultHtml = await _requestText(
      dio,
      'POST',
      '/allRecord.aspx',
      data: {
        '__EVENTTARGET': '',
        '__EVENTARGUMENT': '',
        '__VIEWSTATE': vs,
        '__VIEWSTATEGENERATOR': vsg,
        '__EVENTVALIDATION': ev,
        'txtstart': _formatIsoDate(range.start),
        'txtend': _formatIsoDate(range.end),
        'btnser': '查询',
      },
    );

    final records = _parseAllRecordUsage(resultHtml);
    final totalPages = _parseAllRecordTotalPages(resultHtml);
    for (var page = 2; page <= totalPages; page++) {
      final pageHtml = await _requestText(
        dio,
        'GET',
        '/allRecord.aspx?pu=$page',
      );
      records.addAll(_parseAllRecordUsage(pageHtml));
    }

    _sortDailyUsage(records);
    talker.debug(
      '[NET] 电费DXQ\n${_formatIsoDate(range.start)} 至 ${_formatIsoDate(range.end)} 获取${records.length}条用电记录',
    );
    return records;
  }

  ({DateTime start, DateTime end}) _resolveDateRange(
    String? startDate,
    String? endDate,
  ) {
    final startInput = startDate?.trim() ?? '';
    final endInput = endDate?.trim() ?? '';
    if (startInput.isEmpty && endInput.isEmpty) {
      final now = DateTime.now();
      return (
        start: DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 30)),
        end: DateTime(now.year, now.month, now.day),
      );
    }

    final end = endInput.isNotEmpty
        ? _parseQueryDate(endInput, monthEnd: true)
        : _parseQueryDate(startInput, monthEnd: true);
    final start = startInput.isNotEmpty
        ? _parseQueryDate(startInput)
        : end?.subtract(const Duration(days: 30));
    if (start == null || end == null) {
      throw const PowerQueryException('日期格式无效');
    }
    if (end.isBefore(start)) {
      throw const PowerQueryException('结束日期不能早于开始日期');
    }

    return (start: start, end: end);
  }

  DateTime? _parseQueryDate(String value, {bool monthEnd = false}) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?$')
        .firstMatch(value);
    if (match == null) return null;

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final dayText = match.group(3);
    if (month < 1 || month > 12) return null;
    final day = dayText != null
        ? int.parse(dayText)
        : monthEnd
        ? DateTime(year, month + 1, 0).day
        : 1;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String _formatIsoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _legacyDateInRange(
    String value,
    DateTime month,
    ({DateTime start, DateTime end}) range,
  ) {
    final match = RegExp(r'^(\d{1,2})月(\d{1,2})日').firstMatch(value);
    if (match == null) return false;
    final date = DateTime(
      month.year,
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
    return !date.isBefore(range.start) && !date.isAfter(range.end);
  }

  void _sortDailyUsage(List<PowerDailyUsage> usage) {
    usage.sort((a, b) => b.dateValue.compareTo(a.dateValue));
  }

  List<PowerDailyUsage> _parseAllRecordUsage(String html) {
    final doc = html_parser.parse(html);
    final usedSection = doc.querySelector('#upUsedRecord');
    if (usedSection == null) return [];

    final result = <PowerDailyUsage>[];
    final rows = usedSection.querySelectorAll('table tr');
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 3) {
        final rawDate = _normalizeText(cells[0].text);
        final usage = _normalizeText(cells[2].text);
        if (RegExp(r'\d{4}-\d{1,2}-\d{1,2}').hasMatch(rawDate) &&
            RegExp(r'\d').hasMatch(usage)) {
          result.add(
            PowerDailyUsage(
              date: _formatChineseDate(rawDate),
              usage: usage,
              isoDate: _normalizeIsoDate(rawDate),
            ),
          );
        }
      }
    }
    return result;
  }

  String? _dateSuffix(int year, int month, int day) {
    final today = DateTime.now();
    final diff = DateTime(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime(year, month, day)).inDays;
    return switch (diff) {
      1 => '昨天',
      2 => '前天',
      _ => null,
    };
  }

  String _formatChineseDate(String isoDate) {
    final m = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(isoDate);
    if (m == null) return isoDate;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    final suffix = _dateSuffix(year, month, day);
    return suffix != null ? '$month月$day日 [$suffix]' : '$month月$day日';
  }

  String? _normalizeIsoDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(value);
    if (match == null) return null;
    return '${match.group(1)}-${int.parse(match.group(2)!).toString().padLeft(2, '0')}-${int.parse(match.group(3)!).toString().padLeft(2, '0')}';
  }

  String _addDateSuffix(String dateStr, int year, int month) {
    final m = RegExp(r'(\d{1,2})月(\d{1,2})日').firstMatch(dateStr);
    if (m != null) {
      final mo = int.parse(m.group(1)!);
      final d = int.parse(m.group(2)!);
      final suffix = _dateSuffix(year, mo, d);
      if (suffix != null) return '$dateStr [$suffix]';
    }
    return dateStr;
  }

  int _parseAllRecordTotalPages(String html) {
    final doc = html_parser.parse(html);
    final usedSection = doc.querySelector('#upUsedRecord');
    if (usedSection == null) return 1;
    final pagerText = usedSection.querySelector('.pageer')?.text ?? '';
    final match = RegExp(r'共\s*(\d+)\s*页').firstMatch(pagerText);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  Future<String> _postDxqForm(
    Dio dio, {
    required String viewState,
    required String viewStateGenerator,
    required String building,
    required String floor,
    required String roomId,
    bool submit = false,
    String radio = 'allR',
  }) {
    final data = <String, Object>{
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      'drlouming': building,
      'drceng': floor,
      'drfangjian': roomId,
      'radio': radio,
    };
    if (submit) {
      data['ImageButton1.x'] = '30';
      data['ImageButton1.y'] = '12';
    }

    return _requestText(dio, 'POST', '/', data: data);
  }

  Future<String> _requestText(
    Dio dio,
    String method,
    String path, {
    Map<String, Object>? data,
    Map<String, String>? headers,
    int redirectCount = 0,
  }) async {
    try {
      final response = await dio.request<List<int>>(
        path,
        data: data,
        options: Options(
          method: method,
          headers: headers,
          contentType: data == null ? null : Headers.formUrlEncodedContentType,
          responseType: ResponseType.bytes,
          followRedirects: false,
        ),
      );

      final location = response.headers.value('location');
      final statusCode = response.statusCode ?? 0;
      if (location != null &&
          statusCode >= 300 &&
          statusCode < 400 &&
          redirectCount < 5) {
        final redirectUri = response.realUri.resolve(location);
        return await _requestText(
          dio,
          'GET',
          redirectUri.toString(),
          headers: headers,
          redirectCount: redirectCount + 1,
        );
      }

      return _decodeResponse(
        response.data ?? const <int>[],
        response.headers.value(Headers.contentTypeHeader),
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const PowerQueryException('上游请求超时');
      }
      throw const PowerQueryException('上游请求失败');
    }
  }

  String _decodeResponse(List<int> bytes, String? contentType) {
    final charsetMatch = RegExp(
      r'charset\s*=\s*([^\s;]+)',
      caseSensitive: false,
    ).firstMatch(contentType ?? '');
    final charset = charsetMatch?.group(1)?.toLowerCase();

    if (charset == null || charset == 'utf-8' || charset == 'utf8') {
      return utf8.decode(bytes, allowMalformed: true);
    }

    final encoding = Encoding.getByName(charset);
    if (encoding != null) {
      return encoding.decode(bytes);
    }

    return latin1.decode(bytes);
  }

  String _getInputValue(Document document, String inputId) {
    final input = document.querySelector('input#$inputId');
    final value = input?.attributes['value'];
    if (value == null) {
      throw PowerQueryException('页面中未找到字段 $inputId');
    }
    return value;
  }

  void _parseLoginResult(String responseText) {
    final text = _normalizeText(responseText).toLowerCase();
    if (text.contains('success: true')) {
      return;
    }

    final messageMatch = RegExp(r"msg:'([^']+)'").firstMatch(responseText);
    final message = messageMatch?.group(1) ?? '登录失败';
    if (_normalizeText(message).contains('密码不正确')) {
      throw const PowerQueryException('默认密码被篡改，待解决');
    }
    throw PowerQueryException(message);
  }

  Map<String, Object> _parseLegacyConsumeHistory(
    String html,
    int year,
    int month,
  ) {
    if (html.contains('网络超时或者您还没有登录')) {
      throw const PowerQueryException('读取 consumeHistory 失败，服务端认为当前会话未登录');
    }

    final document = html_parser.parse(html);
    final balanceRows = _getTableRows(_findTableContaining(document, '帐户余额'));
    if (balanceRows.length < 5) {
      throw const PowerQueryException('consumeHistory 页面结构异常');
    }

    final balanceSection = _zipHeadersValues(balanceRows[3], balanceRows[4]);
    return {
      'monthUsage': balanceSection['本月用电'] ?? '',
      'available': balanceSection['本月剩余'] ?? '',
      'dailyUsage': _parseDailyUsage(document, year, month),
    };
  }

  List<List<String>> _getTableRows(Element table) {
    final rows = <List<String>>[];
    for (final tr in table.querySelectorAll('tr')) {
      final cells = tr
          .querySelectorAll('td')
          .map((cell) => _normalizeText(cell.text))
          .where((cell) => cell.isNotEmpty)
          .toList();
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
    return rows;
  }

  Element _findTableContaining(Document document, String keyword) {
    final candidates = <Element>[];
    for (final table in document.querySelectorAll('table')) {
      if (_normalizeText(table.text).contains(keyword)) {
        candidates.add(table);
      }
    }

    if (candidates.isEmpty) {
      throw PowerQueryException("页面中未找到包含 '$keyword' 的表格");
    }

    candidates.sort(
      (left, right) =>
          _normalizeText(left.text).length
              .compareTo(_normalizeText(right.text).length),
    );
    return candidates.first;
  }

  Map<String, String> _zipHeadersValues(
    List<String> headers,
    List<String> values,
  ) {
    final result = <String, String>{};
    for (
      var index = 0;
      index < headers.length && index < values.length;
      index++
    ) {
      result[headers[index].replaceAll('（', '(').replaceAll('）', ')')] =
          values[index];
    }
    return result;
  }

  List<PowerDailyUsage> _parseDailyUsage(
    Document document,
    int year,
    int month,
  ) {
    final table = _findTableContaining(document, '用电明细');
    final result = <PowerDailyUsage>[];

    for (final cell in table.querySelectorAll('td.table-td')) {
      final spans = cell.querySelectorAll('span');
      if (spans.length < 2) {
        continue;
      }

      var date = _normalizeText(spans[0].text);
      final usage = _normalizeText(spans[1].text);
      if (date.isEmpty || usage.isEmpty || usage == '&') {
        continue;
      }
      if (!RegExp(r'\d').hasMatch(usage)) {
        continue;
      }

      date = _addDateSuffix(date, year, month);
      final dateMatch = RegExp(r'^(\d{1,2})月(\d{1,2})日').firstMatch(date);
      final isoDate = dateMatch == null
          ? null
          : '$year-${int.parse(dateMatch.group(1)!).toString().padLeft(2, '0')}-${int.parse(dateMatch.group(2)!).toString().padLeft(2, '0')}';
      result.add(PowerDailyUsage(date: date, usage: usage, isoDate: isoDate));
    }

    return result;
  }

  String _parseDxqAvailable(String html) {
    final document = html_parser.parse(html);
    final numberSpans = document.querySelectorAll('span.number.orange');
    if (numberSpans.length >= 3) {
      final totalAvailable = _extractFirstNumber(numberSpans[2].text);
      if (totalAvailable != null) {
        return totalAvailable;
      }
    }

    final header = document.querySelector('h6');
    if (header != null) {
      final matches = RegExp(r'([0-9]+(?:\.[0-9]+)?)')
          .allMatches(_normalizeText(header.text))
          .toList();
      if (matches.length >= 3) {
        return matches[2].group(1) ?? '-';
      }
      if (matches.isNotEmpty) {
        return matches.last.group(1) ?? '-';
      }
    }

    final spanMatches = RegExp(
      r'<span[^>]*class="number orange"[^>]*>\s*([0-9]+(?:\.[0-9]+)?)\s*</span>',
      caseSensitive: false,
    ).allMatches(html).toList();
    if (spanMatches.length >= 3) {
      return spanMatches[2].group(1) ?? '-';
    }

    throw const PowerQueryException('dxq 页面中未找到余额信息');
  }

  String? _extractFirstNumber(String text) {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?)').firstMatch(text);
    return match?.group(1);
  }

  PowerQueryData _buildQueryData(
    Map<String, Object> raw,
    _EndpointConfig endpoint,
  ) {
    if (endpoint.mode == _EndpointMode.dxq) {
      final dailyUsage = List<PowerDailyUsage>.of(
        (raw['dailyUsage'] as List<PowerDailyUsage>?) ?? const [],
      );
      _sortDailyUsage(dailyUsage);
      final available = raw['available'] as String? ?? '-';
      String? monthUsage;
      if (dailyUsage.isNotEmpty) {
        var total = 0.0;
        for (final item in dailyUsage) {
          total += double.tryParse(item.usage) ?? 0;
        }
        monthUsage = total.toStringAsFixed(2);
      }
      return PowerQueryData(
        price: endpoint.price,
        available: available,
        monthUsage: monthUsage,
        estDays: _estimateDaysLeft(available, dailyUsage),
        dailyUsage: dailyUsage,
      );
    }

    final available = _normalizeLegacyMetric(
      raw['available'] as String? ?? '',
      endpoint,
    );
    final dailyUsage = List<PowerDailyUsage>.of(
      (raw['dailyUsage'] as List<PowerDailyUsage>?) ?? const [],
    );
    _sortDailyUsage(dailyUsage);
    return PowerQueryData(
      price: endpoint.price,
      available: available,
      monthUsage: _normalizeLegacyMetric(
        raw['monthUsage'] as String? ?? '',
        endpoint,
      ),
      estDays: _estimateDaysLeft(available, dailyUsage),
      dailyUsage: dailyUsage,
    );
  }

  String _normalizeLegacyMetric(String value, _EndpointConfig endpoint) {
    if (endpoint.shouldDivideByPrice) {
      return _divideByPrice(value, endpoint.price);
    }
    final normalized = _normalizeText(value);
    return normalized.isEmpty ? '-' : normalized;
  }

  String _divideByPrice(String value, String price) {
    final amount = double.tryParse(value);
    final unitPrice = double.tryParse(price);
    if (amount == null || unitPrice == null || unitPrice <= 0) {
      return '-';
    }
    return (amount / unitPrice).toStringAsFixed(2);
  }

  String? _estimateDaysLeft(
    String available,
    List<PowerDailyUsage> dailyUsage,
  ) {
    final availableValue = double.tryParse(available);
    if (availableValue == null) {
      return null;
    }

    final usageValues = <double>[];
    for (final item in dailyUsage) {
      final value = double.tryParse(item.usage);
      if (value != null && value > 0) {
        usageValues.add(value);
      }
    }

    if (usageValues.length < _estDaysMin) {
      return '样本不足';
    }

    final recent = usageValues.take(_estDaysMin).toList();
    final totalUsage = recent.fold<double>(0, (sum, value) => sum + value);
    final averageUsage = totalUsage / recent.length;
    if (averageUsage <= 0) {
      return null;
    }

    return (availableValue / averageUsage).floor().toString();
  }

  String _normalizeText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll('\u3000', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeRoomId(String value) => value.trim().toUpperCase();

  String _hashBytes(List<int> bytes) => md5.convert(bytes).toString();

  String _md5Hex(String text) => md5.convert(utf8.encode(text)).toString();
}

class RoomRecord {
  final String endpoint;
  final String roomName;
  final String roomId;
  final String password;

  const RoomRecord({
    required this.endpoint,
    required this.roomName,
    required this.roomId,
    required this.password,
  });
}

class _EndpointConfig {
  final String url;
  final _EndpointMode mode;
  final Duration timeout;
  final String price;
  final bool shouldDivideByPrice;
  final String loginPath;
  final String consumeHistoryPath;

  const _EndpointConfig({
    required this.url,
    required this.mode,
    required this.timeout,
    required this.price,
    this.shouldDivideByPrice = true,
    this.loginPath = '',
    this.consumeHistoryPath = '',
  });
}

enum _EndpointMode { legacy, dxq }
