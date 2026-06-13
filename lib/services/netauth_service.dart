import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import 'cas_service.dart';
import 'dio_factory.dart';

class NetAuthInfo {
  final String name;
  final String account;
  final String className;
  final String group;
  final String status;
  final double usedHours;
  final double usedFlowGb;
  final double downFlowGb;
  final double upFlowGb;
  final int maxDevices;

  const NetAuthInfo({
    required this.name,
    required this.account,
    required this.className,
    required this.group,
    required this.status,
    required this.usedHours,
    required this.usedFlowGb,
    required this.downFlowGb,
    required this.upFlowGb,
    required this.maxDevices,
  });

  factory NetAuthInfo.fromJson(Map<String, dynamic> user) {
    final group = (user['serviceDefault'] as Map<String, dynamic>?) ?? {};
    final userGroup = (user['userGroup'] as Map<String, dynamic>?) ?? {};
    return NetAuthInfo(
      name: '${user['userRealName'] ?? ''}',
      account: '${user['userName'] ?? ''}',
      className: '${user['memo'] ?? ''}',
      group: '${group['defaultName'] ?? ''}',
      status: user['useFlag'] == 1 ? '正常' : '停用',
      usedHours: ((user['useTime'] as num?) ?? 0) / 60,
      usedFlowGb: ((user['useFlow'] as num?) ?? 0) / 1024,
      downFlowGb: ((user['internetDownFlow'] as num?) ?? 0) / 1024,
      upFlowGb: ((user['internetUpFlow'] as num?) ?? 0) / 1024,
      maxDevices: (userGroup['ipMaxCount'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'account': account,
        'className': className,
        'group': group,
        'status': status,
        'usedHours': usedHours,
        'usedFlowGb': usedFlowGb,
        'downFlowGb': downFlowGb,
        'upFlowGb': upFlowGb,
        'maxDevices': maxDevices,
      };

  factory NetAuthInfo.fromCache(Map<String, dynamic> j) => NetAuthInfo(
        name: j['name'] as String,
        account: j['account'] as String,
        className: j['className'] as String,
        group: j['group'] as String,
        status: j['status'] as String,
        usedHours: (j['usedHours'] as num).toDouble(),
        usedFlowGb: (j['usedFlowGb'] as num).toDouble(),
        downFlowGb: (j['downFlowGb'] as num).toDouble(),
        upFlowGb: (j['upFlowGb'] as num).toDouble(),
        maxDevices: j['maxDevices'] as int,
      );
}

class NetAuthDevice {
  final bool online;
  final String mac;
  final String type;
  final String lastTime;
  final String ip;

  const NetAuthDevice({
    required this.online,
    required this.mac,
    required this.type,
    required this.lastTime,
    required this.ip,
  });

  Map<String, dynamic> toJson() => {
        'online': online,
        'mac': mac,
        'type': type,
        'lastTime': lastTime,
        'ip': ip,
      };

  factory NetAuthDevice.fromCache(Map<String, dynamic> j) => NetAuthDevice(
        online: j['online'] as bool,
        mac: j['mac'] as String,
        type: j['type'] as String,
        lastTime: j['lastTime'] as String,
        ip: j['ip'] as String,
      );
}

class NetAuthResult {
  final NetAuthInfo info;
  final List<NetAuthDevice> devices;

  const NetAuthResult({required this.info, required this.devices});

  Map<String, dynamic> toJson() => {
        'info': info.toJson(),
        'devices': devices.map((d) => d.toJson()).toList(),
      };

  factory NetAuthResult.fromCache(Map<String, dynamic> j) => NetAuthResult(
        info: NetAuthInfo.fromCache(j['info'] as Map<String, dynamic>),
        devices: (j['devices'] as List)
            .map((d) => NetAuthDevice.fromCache(d as Map<String, dynamic>))
            .toList(),
      );
}

class NetAuthService {
  static String _extractCheckcode(String html) {
    final match = RegExp(
      r'name=["\x27]checkcode["\x27][^>]*value=["\x27]([^"\x27]*)',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) throw AuthException('checkcode not found');
    return match.group(1) ?? '';
  }

  static String _extractErrorTip(String html) {
    final match = RegExp(r"\}\)\('([^']*?)'\);").firstMatch(html);
    return match?.group(1) ?? '';
  }

  static Map<String, dynamic> _extractUserJson(String html) {
    final prefix = RegExp(r'\}\)\(');
    final match = prefix.firstMatch(html);
    if (match == null) return {};
    final start = match.end;
    if (start >= html.length || html[start] != '{') return {};
    var depth = 0;
    var end = start;
    for (var i = start; i < html.length; i++) {
      if (html[i] == '{') depth++;
      if (html[i] == '}') depth--;
      if (depth == 0) {
        end = i + 1;
        break;
      }
    }
    if (depth != 0) return {};
    try {
      return jsonDecode(html.substring(start, end)) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String _extractAjaxCsrf(String html) {
    final match =
        RegExp(r'ajaxCsrfToken.*?["\x27]([a-f0-9-]{36})["\x27]').firstMatch(html);
    if (match == null) throw AuthException('ajaxCsrfToken not found');
    return match.group(1)!;
  }

  static String _extractFormCsrf(String html) {
    final match = RegExp(
      r'name=["\x27]csrftoken["\x27][^>]*value=["\x27]([^"\x27]*)',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) throw AuthException('csrftoken not found');
    return match.group(1) ?? '';
  }

  static Map<String, String> _extractOperatorValues(String html) {
    final values = <String, String>{};
    for (final field in [
      'FLDEXTRA1', 'FLDEXTRA2', 'FLDEXTRA3',
      'FLDEXTRA4', 'FLDEXTRA5', 'FLDEXTRA6',
    ]) {
      final match = RegExp(
        'name=["\x27]$field["\x27][^>]*value=["\x27]([^"\x27]*)',
        caseSensitive: false,
      ).firstMatch(html);
      values[field] = match?.group(1) ?? '';
    }
    return values;
  }

  static String _extractSwalMessage(String html) {
    final matches = RegExp(r"\}\)\('([^']*)'\)").allMatches(html);
    String msg = '';
    for (final m in matches) {
      final v = m.group(1) ?? '';
      if (v.isNotEmpty) msg = v.replaceAll(r'\n', '').trim();
    }
    return msg;
  }

  static List<NetAuthDevice> _parseDevices(Map<String, dynamic> data) {
    final rows = (data['rows'] as List?) ?? [];
    return rows
        .where((row) => row is List && row.length >= 5)
        .map((row) => NetAuthDevice(
              online: row[0] == '1',
              mac: '${row[1]}',
              type: '${row[2]}',
              lastTime: '${row[3]}',
              ip: '${row[4]}',
            ))
        .toList();
  }

  Dio _createDio() {
    return DioFactory.createNaked(
      cookieJar: CookieJar(),
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    );
  }

  Future<Dio> _doLogin(Dio dio, String account, String password) async {
    final loginPage = await dio.get<String>(
      '$netAuthBaseUrl/login',
      options: Options(
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (loginPage.statusCode != 200) {
      throw AuthException('无法访问登录页');
    }

    final checkcode = _extractCheckcode(loginPage.data ?? '');

    await dio.get(
      '$netAuthBaseUrl/login/randomCode',
      queryParameters: {'t': '0.1'},
      options: Options(validateStatus: (s) => s != null && s < 500),
    );

    final loginResp = await dio.post<String>(
      '$netAuthBaseUrl/login/verify',
      data: {
        'account': account,
        'password': password,
        'checkcode': checkcode,
        'foo': '',
        'bar': '',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null && (s < 400 || s == 302),
        headers: {'Referer': '$netAuthBaseUrl/login/'},
      ),
    );

    if (loginResp.statusCode != 302) {
      throw AuthException('登录失败');
    }

    final location = loginResp.headers.value('location') ?? '';
    if (!location.contains('dashboard')) {
      final redirect = await dio.get<String>(
        'http://211.87.126.147:8080$location',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final tip = _extractErrorTip(redirect.data ?? '');
      if (tip.contains('密码') || tip.contains('账号')) {
        throw AuthException(tip);
      }
      throw AuthException(tip.isNotEmpty ? tip : '登录失败');
    }

    return dio;
  }

  Future<NetAuthResult> login(String account, String password) async {
    final dio = _createDio();
    try {
      await _doLogin(dio, account, password);

      final userPage = await dio.get<String>(
        '$netAuthBaseUrl/service/myMac',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final userJson = _extractUserJson(userPage.data ?? '');
      if (userJson.isEmpty) throw AuthException('无法获取用户信息');
      final info = NetAuthInfo.fromJson(userJson);

      final macResp = await dio.get<Map<String, dynamic>>(
        '$netAuthBaseUrl/service/getMacList',
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final devices = _parseDevices(macResp.data ?? {});

      return NetAuthResult(info: info, devices: devices);
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> unbindMac(
    String account,
    String password,
    String mac,
  ) async {
    final dio = _createDio();
    try {
      await _doLogin(dio, account, password);

      final macPage = await dio.get<String>(
        '$netAuthBaseUrl/service/myMac',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final csrf = _extractAjaxCsrf(macPage.data ?? '');

      final cleanMac =
          mac.replaceAll('-', '').replaceAll(':', '').toUpperCase();

      final resp = await dio.get<String>(
        '$netAuthBaseUrl/service/unbindmac',
        queryParameters: {'mac': cleanMac, 'ajaxCsrfToken': csrf},
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final msg = _extractSwalMessage(resp.data ?? '');
      if (msg.isEmpty || msg.contains('失败')) {
        throw AuthException(msg.isNotEmpty ? msg : '解绑失败');
      }
      return msg;
    } finally {
      dio.close(force: true);
    }
  }

  static const _carrierFields = {
    '电信': ('FLDEXTRA5', 'FLDEXTRA6'),
    '移动': ('FLDEXTRA1', 'FLDEXTRA2'),
    '联通': ('FLDEXTRA3', 'FLDEXTRA4'),
  };

  static List<String> get carriers => _carrierFields.keys.toList();

  Future<String> bindOperator(
    String account,
    String password, {
    required String carrier,
    required String broadbandAccount,
    required String broadbandPassword,
  }) async {
    final fields = _carrierFields[carrier];
    if (fields == null) {
      throw AuthException('运营商须为: ${_carrierFields.keys.join(', ')}');
    }

    final dio = _createDio();
    try {
      await _doLogin(dio, account, password);

      final opPage = await dio.get<String>(
        '$netAuthBaseUrl/service/operatorId',
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      final html = opPage.data ?? '';
      final csrf = _extractFormCsrf(html);
      final values = _extractOperatorValues(html);

      values[fields.$1] = broadbandAccount;
      values[fields.$2] = broadbandPassword;

      final resp = await dio.post<String>(
        '$netAuthBaseUrl/service/bind-operator',
        data: {'csrftoken': csrf, ...values},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
          headers: {'Referer': '$netAuthBaseUrl/service/operatorId'},
        ),
      );

      final msg = _extractSwalMessage(resp.data ?? '');
      if (msg.isEmpty || msg.contains('失败')) {
        throw AuthException(msg.isNotEmpty ? msg : '绑定失败');
      }
      return msg;
    } finally {
      dio.close(force: true);
    }
  }
}
