import 'package:dio/dio.dart';

import '../constants/network_config.dart';
import '../constants/semester_config.dart';
import '../constants/time_slots.dart';
import '../models/course.dart';
import '../utils/course_text_parser.dart';
import '../utils/week_calculator.dart';
import 'cas_service.dart';

class LoginResult {
  final String? studentId;
  final String? studentName;
  final List<Course> courses;

  LoginResult({this.studentId, this.studentName, required this.courses});
}

class ExamItem {
  final String courseId;
  final String title;
  final String time;
  final String location;
  final String campus;
  final String seat;
  final String examName;
  final String teacher;
  final String className;
  final String college;
  final String credit;
  final String examType;
  final String note;
  final bool isResit;

  const ExamItem({
    required this.courseId,
    required this.title,
    required this.time,
    required this.location,
    required this.campus,
    required this.seat,
    required this.examName,
    required this.teacher,
    required this.className,
    required this.college,
    required this.credit,
    required this.examType,
    required this.note,
    required this.isResit,
  });
}

class ExamResult {
  final String? studentId;
  final String? studentName;
  final List<ExamItem> exams;

  ExamResult({this.studentId, this.studentName, required this.exams});
}

class AuthService {
  final _casService = CasService();

  Future<LoginResult> loginAndFetch(String studentId, String password) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      return await _fetchSchedule(session.dio);
    } finally {
      session.close();
    }
  }

  Future<ExamResult> fetchExams(String studentId, String password) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      return await _fetchExams(session.dio);
    } finally {
      session.close();
    }
  }

  Future<(LoginResult, ExamResult)> loginAndFetchAll(
    String studentId,
    String password,
  ) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      final results = await Future.wait([
        _fetchSchedule(session.dio),
        _fetchExams(session.dio),
      ]);
      return (results[0] as LoginResult, results[1] as ExamResult);
    } finally {
      session.close();
    }
  }

  Future<LoginResult> _fetchSchedule(Dio dio) async {
    final (year, term) = getCurrentSchoolTerm();
    final xqm = term * term * 3;

    final scheduleResp = await dio.post(
      '$jwBaseUrl/kbcx/xskbcx_cxXsKb.html?gnmkdm=N2151',
      data: {'xnm': year.toString(), 'xqm': xqm.toString()},
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final payload = scheduleResp.data;
    if (payload is String && payload.contains('用户登录')) {
      throw AuthException('会话已过期');
    }

    final data = payload as Map<String, dynamic>;
    if (!data.containsKey('kbList')) {
      throw AuthException('未获取到课表数据');
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
        throw AuthException('解析课程"$title"失败：星期信息无效');
      }

      final sessions = parseSessionRanges(
        c['jc']?.toString() ?? '',
        minSession: 1,
        maxSession: kTimeSlots.length,
      );
      if (sessions == null) {
        throw AuthException('解析课程"$title"失败：节次信息无效');
      }

      final weeks = parseWeekRanges(
        c['zcd']?.toString() ?? '',
        maxWeek: semesterTotalWeeks,
      );
      if (weeks == null) {
        throw AuthException('解析课程"$title"失败：周次信息无效');
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

  Future<ExamResult> _fetchExams(Dio dio) async {
    final (year, term) = getCurrentSchoolTerm();
    final xqm = term * term * 3;

    final examResp = await dio.post(
      '$jwBaseUrl/kwgl/kscx_cxXsksxxIndex.html?doType=query&gnmkdm=N358105',
      data: {
        'xnm': year.toString(),
        'xqm': xqm.toString(),
        '_search': 'false',
        'queryModel.showCount': '100',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
        'time': '0',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final payload = examResp.data;
    if (payload is String && payload.contains('用户登录')) {
      throw AuthException('会话已过期');
    }

    final data = payload as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    if (items.isEmpty) {
      return ExamResult(exams: []);
    }

    final exams = items.map((i) {
      final credit = i['xf'];
      String creditStr;
      if (credit is num) {
        creditStr =
            credit == credit.toInt() ? credit.toInt().toString() : '$credit';
      } else {
        creditStr = credit?.toString() ?? '';
      }

      return ExamItem(
        courseId: (i['kch'] ?? '') as String,
        title: (i['kcmc'] ?? '') as String,
        time: (i['kssj'] ?? '') as String,
        location: (i['cdmc'] ?? '') as String,
        campus: (i['cdxqmc'] ?? '') as String,
        seat: (i['zwh'] ?? '') as String,
        examName: (i['ksmc'] ?? '') as String,
        teacher: (i['jsxx'] ?? '') as String,
        className: (i['jxbmc'] ?? '') as String,
        college: (i['kkxy'] ?? '') as String,
        credit: creditStr,
        examType: (i['ksfs'] ?? '') as String,
        note: (i['bz1'] ?? '') as String,
        isResit: '${i['cxbj'] ?? ''}' != '否',
      );
    }).toList();

    return ExamResult(
      studentId: (items.first['xh'] ?? '') as String?,
      studentName: (items.first['xm'] ?? '') as String?,
      exams: exams,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
