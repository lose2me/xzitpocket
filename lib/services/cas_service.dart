import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import '../utils/cas_encrypt.dart';
import 'debug_log_service.dart';
import 'dio_factory.dart';

class CasSession {
  final Dio dio;
  final CookieJar jar;

  CasSession(this.dio, this.jar);

  void close() => dio.close(force: true);
}

class CasService {
  static bool? _restAvailable;

  /// Get a Service Ticket for [serviceUrl] via REST protocol.
  /// Returns null if REST is unavailable.
  Future<String?> getServiceTicket(
    String username,
    String password,
    String serviceUrl,
  ) async {
    if (_restAvailable == false) return null;
    final jar = CookieJar();
    final dio = _createDio(jar);
    try {
      final tgtUrl = await _restGetTgt(dio, username, password);
      final st = await _restGetSt(dio, tgtUrl, serviceUrl);
      _restAvailable = true;
      return st;
    } on _RestUnavailableException {
      _restAvailable = false;
      return null;
    } on AuthException {
      rethrow;
    } catch (_) {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  Future<CasSession> loginCas(
    String username,
    String password, {
    String? serviceUrl,
  }) async {
    if (serviceUrl != null && _restAvailable != false) {
      try {
        return await _restLogin(username, password, serviceUrl: serviceUrl);
      } on _RestUnavailableException {
        _restAvailable = false;
        DebugLogService.instance.log(
          DebugLogCategory.auth, 'CAS REST', '不可用, 回退HTML',
        );
      }
    }
    return _performCasLogin(username, password, serviceUrl: serviceUrl);
  }

  Future<CasSession> loginJw(String username, String password) async {
    if (_restAvailable != false) {
      try {
        return await _restLoginJw(username, password);
      } on _RestUnavailableException {
        _restAvailable = false;
        DebugLogService.instance.log(
          DebugLogCategory.auth, 'CAS REST', '不可用, 回退HTML',
        );
      }
    }
    return _htmlLoginJw(username, password);
  }

  // ── REST Protocol ──

  Future<CasSession> _restLogin(
    String username,
    String password, {
    required String serviceUrl,
  }) async {
    DebugLogService.instance.log(
      DebugLogCategory.auth, 'CAS REST',
      '用户: $username, 服务: $serviceUrl',
    );
    final jar = CookieJar();
    final dio = _createDio(jar);

    try {
      final tgtUrl = await _restGetTgt(dio, username, password);
      final st = await _restGetSt(dio, tgtUrl, serviceUrl);
      final sep = serviceUrl.contains('?') ? '&' : '?';
      await followRedirectsManually(dio, '$serviceUrl${sep}ticket=$st');
      _restAvailable = true;
      DebugLogService.instance.log(
        DebugLogCategory.auth, 'CAS REST', '登录成功: $username',
      );
      return CasSession(dio, jar);
    } on _RestUnavailableException {
      dio.close(force: true);
      rethrow;
    } on AuthException {
      dio.close(force: true);
      rethrow;
    } catch (e) {
      dio.close(force: true);
      throw _RestUnavailableException();
    }
  }

  Future<CasSession> _restLoginJw(String username, String password) async {
    DebugLogService.instance.log(
      DebugLogCategory.auth, 'CAS REST JW', '用户: $username',
    );
    final jar = CookieJar();
    final dio = _createDio(jar);

    try {
      final tgtUrl = await _restGetTgt(dio, username, password);
      final st = await _restGetSt(dio, tgtUrl, jwSsoUrl);

      final sep = jwSsoUrl.contains('?') ? '&' : '?';
      var url = '$jwSsoUrl${sep}ticket=$st';
      for (var i = 0; i < 10; i++) {
        final resp = await dio.get(
          url,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: false,
            validateStatus: (s) =>
                s != null && (s < 400 || s == 302 || s == 301),
          ),
        );

        if (resp.statusCode == 301 || resp.statusCode == 302) {
          final loc = resp.headers.value('location');
          if (loc == null || loc.isEmpty) break;
          url = loc.startsWith('http')
              ? loc
              : Uri.parse(url).resolve(loc).toString();
          continue;
        }

        final body = resp.data as String? ?? '';
        if (resp.statusCode == 200 &&
            !body.contains('用户登录') &&
            !resp.realUri.toString().contains('cas/login')) {
          _restAvailable = true;
          DebugLogService.instance.log(
            DebugLogCategory.auth, 'CAS REST JW', '登录成功: $username',
          );
          return CasSession(dio, jar);
        }
        break;
      }

      dio.close(force: true);
      throw AuthException('教务系统 SSO 登录失败');
    } on _RestUnavailableException {
      dio.close(force: true);
      rethrow;
    } on AuthException {
      dio.close(force: true);
      rethrow;
    } catch (e) {
      dio.close(force: true);
      throw _RestUnavailableException();
    }
  }

  Future<String> _restGetTgt(
    Dio dio,
    String username,
    String password,
  ) async {
    final resp = await dio.post(
      '$casBaseUrl$casRestPath',
      data: {'username': username, 'password': password},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null,
      ),
    );

    if (resp.statusCode == 404 || resp.statusCode == 405) {
      throw _RestUnavailableException();
    }

    if (resp.statusCode == 201) {
      final location = resp.headers.value('location');
      if (location != null && location.isNotEmpty) return location;
      final body = resp.data?.toString() ?? '';
      final match = RegExp(r'action="([^"]*)"').firstMatch(body);
      if (match != null) return match.group(1)!;
      throw _RestUnavailableException();
    }

    if (resp.statusCode == 400) {
      throw AuthException('用户名或密码不正确');
    }

    throw _RestUnavailableException();
  }

  Future<String> _restGetSt(
    Dio dio,
    String tgtUrl,
    String serviceUrl,
  ) async {
    final resp = await dio.post(
      tgtUrl,
      data: {'service': serviceUrl},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (resp.statusCode == 200) {
      final st = (resp.data?.toString() ?? '').trim();
      if (st.isNotEmpty) return st;
    }

    throw AuthException('获取 Service Ticket 失败');
  }

  // ── HTML Login (fallback) ──

  Future<CasSession> _htmlLoginJw(String username, String password) async {
    final session = await _performCasLogin(
      username,
      password,
      logLabel: 'JW SSO',
    );

    var ssoUrl = jwSsoUrl;
    for (var i = 0; i < 10; i++) {
      final resp = await session.dio.get(
        ssoUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (s) =>
              s != null && (s < 400 || s == 302 || s == 301),
        ),
      );

      if (resp.statusCode == 301 || resp.statusCode == 302) {
        final loc = resp.headers.value('location');
        if (loc == null || loc.isEmpty) break;
        ssoUrl = loc.startsWith('http')
            ? loc
            : Uri.parse(ssoUrl).resolve(loc).toString();
        continue;
      }

      final body = resp.data as String? ?? '';
      if (resp.statusCode == 200 &&
          !body.contains('用户登录') &&
          !resp.realUri.toString().contains('cas/login')) {
        DebugLogService.instance.log(
          DebugLogCategory.auth, 'JW SSO 登录成功', username,
        );
        return session;
      }
      break;
    }

    session.close();
    DebugLogService.instance.log(
      DebugLogCategory.error, 'JW SSO 登录失败', username,
    );
    throw AuthException('教务系统 SSO 登录失败');
  }

  Future<CasSession> _performCasLogin(
    String username,
    String password, {
    String? serviceUrl,
    String logLabel = 'CAS',
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      DebugLogService.instance.log(
        DebugLogCategory.auth,
        '$logLabel 登录${attempt > 1 ? ' (重试$attempt/$maxAttempts)' : ''}',
        '用户: $username${serviceUrl != null ? ', 服务: $serviceUrl' : ''}',
      );
      final jar = CookieJar();
      final dio = _createDio(jar);

      var loginUrl = '$casBaseUrl$casLoginPath';
      if (serviceUrl != null) {
        loginUrl += '?service=${Uri.encodeComponent(serviceUrl)}';
      }
      dio.options.headers['Referer'] = loginUrl;

      final page = await dio.get(
        loginUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final html = page.data as String;
      final execution = _extractExecution(html);

      final pkResp = await dio.get('$casBaseUrl$casPubKeyPath');
      final pkJson = pkResp.data as Map<String, dynamic>;
      final encrypted = casEncryptPassword(
        password,
        pkJson['modulus'] as String,
        pkJson['exponent'] as String,
      );

      final resp = await dio.post(
        loginUrl,
        data: {
          'username': username,
          'password': encrypted,
          'execution': execution,
          '_eventId': 'submit',
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) =>
              status != null && (status < 400 || status == 302),
        ),
      );

      if (resp.statusCode == 302) {
        final loc = resp.headers.value('location');
        if (loc != null && loc.isNotEmpty) {
          await followRedirectsManually(dio, loc);
        }
        DebugLogService.instance.log(
          DebugLogCategory.auth, '$logLabel 登录成功', username,
        );
        return CasSession(dio, jar);
      }

      final errMsg = _extractErrorMsg(resp.data as String? ?? '');
      dio.close(force: true);

      final isCredentialErr =
          errMsg.contains('密码') || errMsg.contains('用户名');
      if (isCredentialErr && attempt < maxAttempts) {
        DebugLogService.instance.log(
          DebugLogCategory.auth,
          '$logLabel 登录重试',
          '第$attempt次失败(服务端偶发)，${500 * attempt}ms 后重试',
        );
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }

      DebugLogService.instance.log(
        DebugLogCategory.error, '$logLabel 登录失败', errMsg,
      );
      if (isCredentialErr) {
        throw AuthException('用户名或密码不正确');
      }
      if (errMsg.contains('验证码')) {
        throw AuthException('需要验证码，请稍后再试');
      }
      throw AuthException(errMsg.isNotEmpty ? errMsg : '登录失败');
    }
    throw AuthException('登录失败');
  }

  // ── Helpers ──

  Dio _createDio(CookieJar jar) {
    return DioFactory.createNaked(
      cookieJar: jar,
      connectTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
      ignoreCertificate: true,
    );
  }

  String _extractExecution(String html) {
    var match = RegExp(
      r'name=["\x27]execution["\x27][^>]*value=["\x27]([^"\x27]+)',
      caseSensitive: false,
    ).firstMatch(html);
    match ??= RegExp(
      r'value=["\x27]([^"\x27]+)["\x27][^>]*name=["\x27]execution["\x27]',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) throw AuthException('无法获取 CAS execution');
    return match.group(1)!;
  }

  String _extractErrorMsg(String html) {
    final match = RegExp(
      r'id=["\x27]errormsg["\x27][^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return '';
    return match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }
}

class _RestUnavailableException implements Exception {}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Manually follow redirects so CookieJar is consulted at each hop.
Future<Response<String>> followRedirectsManually(
  Dio dio,
  String url, {
  int maxRedirects = 10,
}) async {
  var currentUrl = url;
  for (var i = 0; i < maxRedirects; i++) {
    final resp = await dio.get<String>(
      currentUrl,
      options: Options(
        responseType: ResponseType.plain,
        followRedirects: false,
        validateStatus: (s) => s != null && (s < 400 || s == 302 || s == 301),
      ),
    );

    if (resp.statusCode == 301 || resp.statusCode == 302) {
      final loc = resp.headers.value('location');
      if (loc == null || loc.isEmpty) return resp;
      currentUrl = loc.startsWith('http')
          ? loc
          : Uri.parse(currentUrl).resolve(loc).toString();
      continue;
    }

    return resp;
  }
  throw AuthException('重定向次数过多');
}
