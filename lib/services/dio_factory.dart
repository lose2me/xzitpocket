import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../constants/network_config.dart';
import 'talker.dart';

class DioFactory {
  DioFactory._();

  static Dio create({
    required String baseUrl,
    required CookieJar cookieJar,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    String userAgent = kUserAgent,
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
            client.badCertificateCallback = (_, _, _) => true;
          }
          return client;
        },
      );
    }
    dio.interceptors.add(_LenientCookieManager(cookieJar));
    dio.interceptors.add(talkerDioLogger);
    return dio;
  }

  static Dio createNaked({
    required CookieJar cookieJar,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    String userAgent = kUserAgent,
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
          client.badCertificateCallback = (_, _, _) => true;
          return client;
        },
      );
    }
    dio.interceptors.add(_LenientCookieManager(cookieJar));
    dio.interceptors.add(talkerDioLogger);
    return dio;
  }
}

class _LenientCookieManager extends CookieManager {
  _LenientCookieManager(super.cookieJar);

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
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
        } catch (e, stackTrace) {
          talker.warning('Set-Cookie 解析失败\n$raw', e, stackTrace);
        }
      }
      if (cookies.isNotEmpty) {
        await cookieJar.saveFromResponse(response.requestOptions.uri, cookies);
      }
    } catch (e, stackTrace) {
      talker.warning('响应 Cookie 保存失败', e, stackTrace);
    }
  }
}
