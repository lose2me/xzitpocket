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
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/146.0.0.0 Safari/537.36';

  Future<CasSession> loginCas(
    String username,
    String password, {
    String? serviceUrl,
  }) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      DebugLogService.instance.log(
        DebugLogCategory.auth,
        'CAS 登录${attempt > 1 ? ' (重试$attempt/$maxAttempts)' : ''}',
        '用户: $username, 服务: ${serviceUrl ?? 'none'}',
      );
      final jar = CookieJar();
      final dio = DioFactory.createNaked(
        cookieJar: jar,
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        ignoreCertificate: true,
      );

      var loginUrl = '$casBaseUrl$casLoginPath';
      if (serviceUrl != null) {
        loginUrl += '?service=${Uri.encodeComponent(serviceUrl)}';
      }
      dio.options.headers['Referer'] = loginUrl;
      dio.options.headers['User-Agent'] = _userAgent;

      final page = await dio.get(
        loginUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final html = page.data as String;
      final execution = _extractExecution(html);

      final pkResp = await dio.get('$casBaseUrl$casPubKeyPath');
      final pkJson = pkResp.data as Map<String, dynamic>;
      final modulus = pkJson['modulus'] as String;
      final exponent = pkJson['exponent'] as String;

      final encrypted = casEncryptPassword(password, modulus, exponent);

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
        DebugLogService.instance.log(DebugLogCategory.auth, 'CAS 登录成功', username);
        return CasSession(dio, jar);
      }

      final errMsg = _extractErrorMsg(resp.data as String? ?? '');
      dio.close(force: true);

      final isCredentialErr =
          errMsg.contains('密码') || errMsg.contains('用户名');
      if (isCredentialErr && attempt < maxAttempts) {
        DebugLogService.instance.log(
          DebugLogCategory.auth,
          'CAS 登录重试',
          '第${attempt}次失败(服务端偶发)，${500 * attempt}ms 后重试',
        );
        await Future.delayed(Duration(milliseconds: 500 * attempt));
        continue;
      }

      DebugLogService.instance.log(DebugLogCategory.error, 'CAS 登录失败', errMsg);
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

  Future<CasSession> loginJw(String username, String password) async {
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      DebugLogService.instance.log(
        DebugLogCategory.auth,
        'JW SSO 登录${attempt > 1 ? ' (重试$attempt/$maxAttempts)' : ''}',
        '用户: $username',
      );
      final jar = CookieJar();
      final dio = DioFactory.createNaked(
        cookieJar: jar,
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        ignoreCertificate: true,
      );

      final loginUrl = '$casBaseUrl$casLoginPath';
      dio.options.headers['Referer'] = loginUrl;
      dio.options.headers['User-Agent'] = _userAgent;

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

      final loginResp = await dio.post(
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
          validateStatus: (s) => s != null && (s < 400 || s == 302),
        ),
      );

      if (loginResp.statusCode != 302) {
        final errMsg = _extractErrorMsg(loginResp.data as String? ?? '');
        dio.close(force: true);

        final isCredentialErr =
            errMsg.contains('密码') || errMsg.contains('用户名');
        if (isCredentialErr && attempt < maxAttempts) {
          DebugLogService.instance.log(
            DebugLogCategory.auth,
            'JW CAS 登录重试',
            '第${attempt}次失败(服务端偶发)，${500 * attempt}ms 后重试',
          );
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        DebugLogService.instance.log(
            DebugLogCategory.error, 'JW CAS 登录失败', errMsg);
        if (isCredentialErr) {
          throw AuthException('用户名或密码不正确');
        }
        throw AuthException(errMsg.isNotEmpty ? errMsg : '登录失败');
      }

      // Manually follow CAS redirect to establish TGC
      final casRedirect = loginResp.headers.value('location');
      if (casRedirect != null && casRedirect.isNotEmpty) {
        await dio.get(
          casRedirect,
          options: Options(
            responseType: ResponseType.plain,
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (s) => s != null && s < 500,
          ),
        );
      }

      // Now GET jwSsoUrl — CookieJar sends TGC, CAS issues ticket via redirects
      var ssoUrl = jwSsoUrl;
      for (var i = 0; i < 10; i++) {
        final resp = await dio.get(
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
              DebugLogCategory.auth, 'JW SSO 登录成功', username);
          return CasSession(dio, jar);
        }
        break;
      }

      dio.close(force: true);
      DebugLogService.instance.log(
          DebugLogCategory.error, 'JW SSO 登录失败', username);
      throw AuthException('教务系统 SSO 登录失败');
    }
    throw AuthException('登录失败');
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
