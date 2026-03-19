import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../constants/network_config.dart';
import '../constants/semester_config.dart';
import '../constants/time_slots.dart';
import '../models/course.dart';
import '../utils/course_text_parser.dart';
import '../utils/rsa_encrypt.dart';
import '../utils/week_calculator.dart';

class LoginResult {
  final String? studentId;
  final String? studentName;
  final List<Course> courses;

  LoginResult({this.studentId, this.studentName, required this.courses});
}

class AuthService {
  Dio _createDio(String baseUrl, CookieJar jar) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/56.0.2924.87 Safari/537.36',
        },
        followRedirects: true,
        maxRedirects: 5,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    return dio;
  }

  /// 登录并获取课表。
  /// - 依次尝试每个 baseUrl：登录 + 获取课表。
  /// - 业务异常（密码错误、验证码）直接抛出不重试。
  /// - 登录或获取课表失败则切换到下一个 baseUrl 重新登录。
  Future<LoginResult> loginAndFetch(String studentId, String password) async {
    Object? lastError;

    for (final baseUrl in baseUrls) {
      final jar = CookieJar();
      final dio = _createDio(baseUrl, jar);

      try {
        await _login(dio, baseUrl, studentId, password);
      } on AuthException {
        rethrow;
      } catch (e) {
        lastError = e;
        continue;
      }

      try {
        return await _fetchSchedule(dio);
      } catch (e) {
        lastError = e;
      }
    }

    throw AuthException('登录或获取课表失败: $lastError');
  }

  // ── 登录 ──

  Future<void> _login(
    Dio dio,
    String baseUrl,
    String studentId,
    String password,
  ) async {
    const loginPath = '/xtgl/login_slogin.html';
    const keyPath = '/xtgl/login_getPublicKey.html';

    dio.options.headers['Referer'] = '$baseUrl$loginPath';

    final loginPage = await dio.get(
      loginPath,
      options: Options(responseType: ResponseType.plain),
    );
    final html = loginPage.data as String;

    if (RegExp(
      r'id=["'
      "'"
      r']yzm["'
      "'"
      r']',
      caseSensitive: false,
    ).hasMatch(html)) {
      throw AuthException('需要验证码，请稍后再试');
    }

    final csrfToken = _extractCsrfToken(html);

    final keyResp = await dio.get(keyPath);
    final keyJson = keyResp.data as Map<String, dynamic>;
    final modulus = keyJson['modulus'] as String;
    final exponent = keyJson['exponent'] as String;

    final encryptedPwd = encryptPassword(password, modulus, exponent);
    final loginResp = await dio.post(
      loginPath,
      data: {'csrftoken': csrfToken, 'yhm': studentId, 'mm': encryptedPwd},
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    final respHtml = loginResp.data as String;
    final tips = _extractTips(respHtml);

    if (tips.contains('用户名或密码')) {
      throw AuthException('用户名或密码不正确');
    }
    if (tips.isNotEmpty) {
      throw AuthException(tips);
    }
  }

  // ── 获取课表 ──

  Future<LoginResult> _fetchSchedule(Dio dio) async {
    final (year, term) = getCurrentSchoolTerm();
    final xqm = term * term * 3;

    final scheduleResp = await dio.post(
      '/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151',
      data: {'xnm': year.toString(), 'xqm': xqm.toString()},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final payload = scheduleResp.data;
    if (payload is String && payload.contains('用户登录')) {
      throw Exception('会话已过期');
    }

    final data = payload as Map<String, dynamic>;
    if (!data.containsKey('kbList')) {
      throw Exception('未获取到课表数据');
    }

    final courses = <Course>[];
    final kbList = (data['kbList'] as List?) ?? [];
    int colorIdx = 0;
    final colorMap = <String, int>{};

    for (final c in kbList) {
      final title = ((c['kcmc'] ?? '') as String).trim();
      if (title.isEmpty) {
        throw AuthException('解析课表失败：存在课程名称为空的数据');
      }

      final courseId = (c['kch_id'] ?? '') as String;
      final colorKey = courseId.isNotEmpty ? courseId : title;
      if (!colorMap.containsKey(colorKey)) {
        colorMap[colorKey] = colorIdx % Course.colors.length;
        colorIdx++;
      }

      final weekday = _parseInt(c['xqj']);
      if (weekday == null || weekday < 1 || weekday > 7) {
        throw AuthException('解析课程“$title”失败：星期信息无效');
      }

      final sessions = parseSessionRanges(
        c['jc']?.toString() ?? '',
        minSession: 1,
        maxSession: kTimeSlots.length,
      );
      if (sessions == null) {
        throw AuthException('解析课程“$title”失败：节次信息无效');
      }

      final weeks = parseWeekRanges(
        c['zcd']?.toString() ?? '',
        maxWeek: semesterTotalWeeks,
      );
      if (weeks == null) {
        throw AuthException('解析课程“$title”失败：周次信息无效');
      }

      courses.add(
        Course(
          title: title,
          teacher: (c['xm'] ?? '') as String,
          weekday: weekday,
          sessions: sessions,
          weeks: weeks,
          campus: (c['xqmc'] ?? '') as String,
          place: (c['cdmc'] ?? '') as String,
          colorIndex: colorMap[colorKey]!,
          courseId: courseId,
        ),
      );
    }

    final xsxx = (data['xsxx'] as Map<String, dynamic>?) ?? {};

    return LoginResult(
      studentId: xsxx['XH'] as String?,
      studentName: xsxx['XM'] as String?,
      courses: courses,
    );
  }

  // ── Helpers ──

  String _extractCsrfToken(String html) {
    var match = RegExp(
      r'id=["\x27]csrftoken["\x27][^>]*value=["\x27]([^"\x27]+)',
      caseSensitive: false,
    ).firstMatch(html);
    match ??= RegExp(
      r'value=["\x27]([^"\x27]+)["\x27][^>]*id=["\x27]csrftoken["\x27]',
      caseSensitive: false,
    ).firstMatch(html);
    if (match == null) throw AuthException('无法获取 csrftoken');
    return match.group(1)!;
  }

  String _extractTips(String html) {
    final match = RegExp(
      r'<p[^>]*id=["\x27]tips["\x27][^>]*>(.*?)</p>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return '';
    return match.group(1)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
