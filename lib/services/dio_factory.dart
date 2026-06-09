import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

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
    if (bypassProxy) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) => 'DIRECT';
          return client;
        },
      );
    }
    dio.interceptors.add(CookieManager(cookieJar));
    return dio;
  }
}
