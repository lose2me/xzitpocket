import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import 'debug_log_service.dart';

const _defaultUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/146.0.0.0 Safari/537.36';

class DioFactory {
  DioFactory._();

  static Dio create({
    required String baseUrl,
    required CookieJar cookieJar,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    String userAgent = _defaultUserAgent,
    bool bypassProxy = false,
    bool ignoreCertificate = false,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'User-Agent': userAgent},
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    if (bypassProxy || ignoreCertificate) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          if (bypassProxy) client.findProxy = (_) => 'DIRECT';
          if (ignoreCertificate) {
            client.badCertificateCallback = (_, __, ___) => true;
          }
          return client;
        },
      );
    }
    dio.interceptors.add(DebugLogService.instance.dioInterceptor);
    dio.interceptors.add(_LenientCookieManager(cookieJar));
    return dio;
  }

  static Dio createNaked({
    required CookieJar cookieJar,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    String userAgent = _defaultUserAgent,
    bool ignoreCertificate = false,
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        headers: {'User-Agent': userAgent},
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    if (ignoreCertificate) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, __, ___) => true;
          return client;
        },
      );
    }
    dio.interceptors.add(DebugLogService.instance.dioInterceptor);
    dio.interceptors.add(_LenientCookieManager(cookieJar));
    return dio;
  }
}

class _LenientCookieManager extends CookieManager {
  _LenientCookieManager(super.cookieJar);

  @override
  Future<void> onResponse(Response response, ResponseInterceptorHandler handler) async {
    await _saveCookiesLenient(response);
    handler.next(response);
  }

  Future<void> _saveCookiesLenient(Response response) async {
    try {
      final setCookies = response.headers[HttpHeaders.setCookieHeader];
      if (setCookies == null || setCookies.isEmpty) return;

      final cookies = <Cookie>[];
      for (final raw in setCookies) {
        try {
          cookies.add(Cookie.fromSetCookieValue(raw));
        } catch (_) {}
      }
      if (cookies.isNotEmpty) {
        await cookieJar.saveFromResponse(
          response.requestOptions.uri,
          cookies,
        );
      }
    } catch (_) {}
  }
}
