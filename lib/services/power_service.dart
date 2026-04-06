import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/io.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class PowerQueryException implements Exception {
  final String message;

  const PowerQueryException(this.message);

  @override
  String toString() => message;
}

class PowerDailyUsage {
  final String date;
  final String usage;

  const PowerDailyUsage({required this.date, required this.usage});
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
}

class PowerService {
  static const _roomDbAssetPath = 'fmd/power/room.db';
  static const _roomDbFileName = 'power_room_v1.db';
  static const _requestTimeout = Duration(seconds: 10);
  static const _estDaysMin = 5;
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/146.0.0.0 Safari/537.36';

  static final Map<String, _EndpointConfig> _endpoints = {
    'zx': _EndpointConfig(
      url: 'http://211.87.126.94/zx',
      mode: _EndpointMode.legacy,
      timeout: _requestTimeout,
      password: '888888',
      price: '0.54',
      shouldDivideByPrice: false,
      loginPath: '/chkuser.fwps',
      consumeHistoryPath: '/consumeHistory.fwps',
    ),
    'cn': _EndpointConfig(
      url: 'http://211.87.126.94/cn',
      mode: _EndpointMode.legacy,
      timeout: _requestTimeout,
      password: '888888',
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

  Future<PowerQueryData> queryRoom(String customId) async {
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
    final dio = _createDio(endpoint, jar);
    try {
      final raw = endpoint.mode == _EndpointMode.dxq
          ? await _queryDxqRoom(dio, room)
          : await _queryLegacyRoom(dio, room, endpoint);
      return _buildQueryData(raw, endpoint);
    } finally {
      dio.close(force: true);
    }
  }

  Future<RoomRecord> _getRoomByCustomId(String customId) async {
    final db = await _openRoomDatabase();
    final rows = await db.query(
      'rooms',
      columns: const ['endpoint', 'roomName', 'roomID'],
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

  Dio _createDio(_EndpointConfig endpoint, CookieJar jar) {
    final dio = Dio(
      BaseOptions(
        baseUrl: endpoint.url,
        connectTimeout: endpoint.timeout,
        receiveTimeout: endpoint.timeout,
        headers: const {'User-Agent': _userAgent},
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
    dio.interceptors.add(CookieManager(jar));
    return dio;
  }

  Future<Map<String, Object>> _queryLegacyRoom(
    Dio dio,
    RoomRecord room,
    _EndpointConfig endpoint,
  ) async {
    await _loginLegacy(dio, room, endpoint);
    final consumeHtml = await _requestText(
      dio,
      'GET',
      endpoint.consumeHistoryPath,
    );
    return _parseLegacyConsumeHistory(consumeHtml);
  }

  Future<void> _loginLegacy(
    Dio dio,
    RoomRecord room,
    _EndpointConfig endpoint,
  ) async {
    final loginPage = await _requestText(dio, 'GET', '/');
    final sessionMatch = RegExp(
      r'g_pswSession\s*=\s*(\d+)',
    ).firstMatch(loginPage);
    final session = sessionMatch?.group(1);
    if (session == null || endpoint.password == null) {
      throw const PowerQueryException('登录页中未找到 g_pswSession');
    }

    final password = _md5Hex(_md5Hex('${endpoint.password}$session'));
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

  Future<Map<String, Object>> _queryDxqRoom(Dio dio, RoomRecord room) async {
    if (room.roomId.length < 4) {
      throw const PowerQueryException('dxq 房间编码无效');
    }

    final landingHtml = await _requestText(dio, 'GET', '/');
    final landingDoc = html_parser.parse(landingHtml);
    final building = room.roomId.substring(0, 2);
    final floor = room.roomId.substring(0, 4);

    final buildingHtml = await _postDxqForm(
      dio,
      viewState: _getInputValue(landingDoc, '__VIEWSTATE'),
      viewStateGenerator: _getInputValue(landingDoc, '__VIEWSTATEGENERATOR'),
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

    return {'available': _parseDxqAvailable(resultHtml)};
  }

  Future<String> _postDxqForm(
    Dio dio, {
    required String viewState,
    required String viewStateGenerator,
    required String building,
    required String floor,
    required String roomId,
    bool submit = false,
  }) {
    final data = <String, Object>{
      '__VIEWSTATE': viewState,
      '__VIEWSTATEGENERATOR': viewStateGenerator,
      'drlouming': building,
      'drceng': floor,
      'drfangjian': roomId,
      'radio': 'allR',
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
        return _requestText(
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

  Map<String, Object> _parseLegacyConsumeHistory(String html) {
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
      'dailyUsage': _parseDailyUsage(document),
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
      (left, right) => _normalizeText(
        left.text,
      ).length.compareTo(_normalizeText(right.text).length),
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

  List<PowerDailyUsage> _parseDailyUsage(Document document) {
    final table = _findTableContaining(document, '用电明细');
    final result = <PowerDailyUsage>[];

    for (final cell in table.querySelectorAll('td.table-td')) {
      final spans = cell.querySelectorAll('span');
      if (spans.length < 2) {
        continue;
      }

      final date = _normalizeText(spans[0].text);
      final usage = _normalizeText(spans[1].text);
      if (date.isEmpty || usage.isEmpty || usage == '&') {
        continue;
      }
      if (!RegExp(r'\d').hasMatch(usage)) {
        continue;
      }

      result.add(PowerDailyUsage(date: date, usage: usage));
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
      final matches = RegExp(
        r'([0-9]+(?:\.[0-9]+)?)',
      ).allMatches(_normalizeText(header.text)).toList();
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
      return PowerQueryData(
        price: endpoint.price,
        available: raw['available'] as String? ?? '-',
      );
    }

    final available = _normalizeLegacyMetric(
      raw['available'] as String? ?? '',
      endpoint,
    );
    final dailyUsage =
        (raw['dailyUsage'] as List<PowerDailyUsage>? ?? const []);
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
      if (value != null) {
        usageValues.add(value);
      }
    }

    if (usageValues.length < _estDaysMin) {
      return '样本不足';
    }

    final totalUsage = usageValues.fold<double>(0, (sum, value) => sum + value);
    final averageUsage = totalUsage / usageValues.length;
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

  const RoomRecord({
    required this.endpoint,
    required this.roomName,
    required this.roomId,
  });
}

class _EndpointConfig {
  final String url;
  final _EndpointMode mode;
  final Duration timeout;
  final String? password;
  final String price;
  final bool shouldDivideByPrice;
  final String loginPath;
  final String consumeHistoryPath;

  const _EndpointConfig({
    required this.url,
    required this.mode,
    required this.timeout,
    this.password,
    required this.price,
    this.shouldDivideByPrice = true,
    this.loginPath = '',
    this.consumeHistoryPath = '',
  });
}

enum _EndpointMode { legacy, dxq }
