import 'package:dio/dio.dart';

import '../constants/network_config.dart';
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

  Map<String, dynamic> toJson() => {
        'courseId': courseId,
        'title': title,
        'time': time,
        'location': location,
        'campus': campus,
        'seat': seat,
        'examName': examName,
        'teacher': teacher,
        'className': className,
        'college': college,
        'credit': credit,
        'examType': examType,
        'note': note,
        'isResit': isResit,
      };

  factory ExamItem.fromJson(Map<String, dynamic> j) => ExamItem(
        courseId: j['courseId'] as String,
        title: j['title'] as String,
        time: j['time'] as String,
        location: j['location'] as String,
        campus: j['campus'] as String,
        seat: j['seat'] as String,
        examName: j['examName'] as String,
        teacher: j['teacher'] as String,
        className: j['className'] as String,
        college: j['college'] as String,
        credit: j['credit'] as String,
        examType: j['examType'] as String,
        note: j['note'] as String,
        isResit: j['isResit'] as bool,
      );
}

class ExamResult {
  final String? studentId;
  final String? studentName;
  final List<ExamItem> exams;

  ExamResult({this.studentId, this.studentName, required this.exams});

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'studentName': studentName,
        'exams': exams.map((e) => e.toJson()).toList(),
      };

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
        studentId: j['studentId'] as String?,
        studentName: j['studentName'] as String?,
        exams: (j['exams'] as List)
            .map((e) => ExamItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Classroom {
  final String name;
  final String type;
  final int seats;
  final String campus;
  final String building;

  const Classroom({
    required this.name,
    required this.type,
    required this.seats,
    required this.campus,
    required this.building,
  });
}

class ClassroomResult {
  final List<Classroom> classrooms;
  final List<String> campuses;
  final Map<String, List<String>> buildingsByCampus;

  const ClassroomResult({
    required this.classrooms,
    required this.campuses,
    required this.buildingsByCampus,
  });
}

class GradeItem {
  final String name;
  final String score;
  final double credit;
  final double gradePoint;
  final String type;
  final String category;
  final String teacher;
  final String examMethod;
  final String year;
  final String term;

  const GradeItem({
    required this.name,
    required this.score,
    required this.credit,
    required this.gradePoint,
    required this.type,
    required this.category,
    required this.teacher,
    required this.examMethod,
    required this.year,
    required this.term,
  });
}

class GradeResult {
  final List<GradeItem> grades;
  final List<String> years;
  final Map<String, List<String>> termsByYear;

  const GradeResult({
    required this.grades,
    required this.years,
    required this.termsByYear,
  });
}

class AcademicCategory {
  final String name;
  final double reqCredits;
  final double earnedCredits;
  final double missingCredits;

  const AcademicCategory({
    required this.name,
    required this.reqCredits,
    required this.earnedCredits,
    required this.missingCredits,
  });
}

class AcademicStatus {
  final double gpa;
  final double totalRequired;
  final double totalEarned;
  final List<AcademicCategory> categories;

  const AcademicStatus({
    required this.gpa,
    required this.totalRequired,
    required this.totalEarned,
    required this.categories,
  });
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

  Future<ClassroomResult> fetchClassrooms(
    String studentId,
    String password, {
    required int week,
    required int weekday,
    required List<int> sessions,
  }) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      return await _fetchClassrooms(session.dio,
          week: week, weekday: weekday, sessions: sessions);
    } finally {
      session.close();
    }
  }

  Future<(GradeResult, AcademicStatus)> fetchGradesAndAcademic(
    String studentId,
    String password,
  ) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      final results = await Future.wait([
        _fetchGrades(session.dio),
        _fetchAcademicStatus(session.dio),
      ]);
      return (results[0] as GradeResult, results[1] as AcademicStatus);
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

  Future<ClassroomResult> _fetchClassrooms(
    Dio dio, {
    required int week,
    required int weekday,
    required List<int> sessions,
  }) async {
    final (year, term) = getCurrentSchoolTerm();
    final xqm = term * term * 3;
    final zcd = (1 << (week - 1)).toString();
    var jcd = 0;
    for (final s in sessions) {
      jcd += 1 << (s - 1);
    }

    await dio.get(
      '$jwBaseUrl/cdjy/cdjy_cxKxcdlb.html?gnmkdm=N2155',
      options: Options(responseType: ResponseType.plain),
    );

    final resp = await dio.post(
      '$jwBaseUrl/cdjy/cdjy_cxKxcdlb.html?doType=query&gnmkdm=N2155',
      data: {
        'xnm': year.toString(),
        'xqm': xqm.toString(),
        'jyfs': '0',
        'zcd': zcd,
        'xqj': weekday.toString(),
        'jcd': jcd.toString(),
        '_search': 'false',
        'queryModel.showCount': '1000',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
        'time': '0',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final payload = resp.data;
    if (payload is String && payload.contains('用户登录')) {
      throw AuthException('会话已过期');
    }

    final data = payload as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    const usefulTypes = {
      '一般教室',
      '多媒体教室',
      '智慧教室',
      '录播教室',
      '俄语教室',
    };

    final classrooms = <Classroom>[];
    final campusSet = <String>{};
    final buildingsByCampus = <String, Set<String>>{};

    for (final item in items) {
      final type = (item['cdlbmc'] ?? '') as String;
      if (!usefulTypes.contains(type)) continue;

      final campus = (item['xqmc'] ?? '') as String;
      final building = (item['jxlmc'] ?? '') as String;

      campusSet.add(campus);
      (buildingsByCampus[campus] ??= <String>{}).add(building);

      classrooms.add(Classroom(
        name: (item['cdmc'] ?? '') as String,
        type: type,
        seats: int.tryParse('${item['zws']}') ?? 0,
        campus: campus,
        building: building,
      ));
    }

    classrooms.sort((a, b) => a.name.compareTo(b.name));

    final campuses = campusSet.toList()..sort();
    final buildingsMap = buildingsByCampus.map(
      (k, v) => MapEntry(k, v.toList()..sort()),
    );

    return ClassroomResult(
      classrooms: classrooms,
      campuses: campuses,
      buildingsByCampus: buildingsMap,
    );
  }

  Future<GradeResult> _fetchGrades(Dio dio) async {
    await dio.get(
      '$jwBaseUrl/cjcx/cjcx_cxDgXscj.html?gnmkdm=N305005',
      options: Options(responseType: ResponseType.plain),
    );

    final resp = await dio.post(
      '$jwBaseUrl/cjcx/cjcx_cxDgXscj.html?doType=query&gnmkdm=N305005',
      data: {
        'xnm': '',
        'xqm': '',
        '_search': 'false',
        'queryModel.showCount': '500',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
        'time': '0',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final payload = resp.data;
    if (payload is String && payload.contains('用户登录')) {
      throw AuthException('会话已过期');
    }

    final data = payload as Map<String, dynamic>;
    final items = (data['items'] as List?) ?? [];

    final yearSet = <String>{};
    final termsByYear = <String, Set<String>>{};
    final grades = <GradeItem>[];

    for (final i in items) {
      final year = (i['xnmmc'] ?? '') as String;
      final term = (i['xqmmc'] ?? '') as String;
      yearSet.add(year);
      (termsByYear[year] ??= <String>{}).add(term);

      final credit = i['xf'];
      final jd = i['jd'];

      grades.add(GradeItem(
        name: (i['kcmc'] ?? '') as String,
        score: '${i['cj'] ?? ''}',
        credit: (credit is num) ? credit.toDouble() : double.tryParse('$credit') ?? 0,
        gradePoint: (jd is num) ? jd.toDouble() : double.tryParse('$jd') ?? 0,
        type: (i['kcxzmc'] ?? '') as String,
        category: (i['kclbmc'] ?? '') as String,
        teacher: (i['jsxm'] ?? '') as String,
        examMethod: (i['khfsmc'] ?? '') as String,
        year: year,
        term: term,
      ));
    }

    final years = yearSet.toList()..sort((a, b) => b.compareTo(a));
    final termsMap = termsByYear.map(
      (k, v) => MapEntry(k, v.toList()..sort()),
    );

    return GradeResult(grades: grades, years: years, termsByYear: termsMap);
  }

  Future<AcademicStatus> _fetchAcademicStatus(Dio dio) async {
    final resp = await dio.get(
      '$jwBaseUrl/xsxy/xsxyqk_cxXsxyqkIndex.html?gnmkdm=N105515&layout=default',
      options: Options(responseType: ResponseType.plain),
    );

    final body = resp.data.toString();
    if (body.contains('用户登录')) {
      throw AuthException('会话已过期');
    }

    final gpaMatch = RegExp(r'GPA）：\s*<font[^>]*>\s*([\d.]+)').firstMatch(body);
    final gpa = double.tryParse(gpaMatch?.group(1) ?? '') ?? 0;

    final totalMatch = RegExp(
      r"title1[^>]*>[^<]*<br\s*/?>\s*最低毕业学分[：:]([\d.]+).*?已获得总学分[：:]([\d.]+)",
    ).firstMatch(body);
    final totalRequired = double.tryParse(totalMatch?.group(1) ?? '') ?? 0;
    final totalEarned = double.tryParse(totalMatch?.group(2) ?? '') ?? 0;

    final catPattern = RegExp(
      r'"(\S+?)&nbsp;"[^:]+yqxf[^:]+:([\d.]+)[^:]+hdxf[^:]+:([\d.]+)[^:]+whdxf[^:]+:([\d.]+)',
    );
    final seen = <String>{};
    final categories = <AcademicCategory>[];
    for (final m in catPattern.allMatches(body)) {
      final name = m.group(1)!;
      final req = double.tryParse(m.group(2)!) ?? 0;
      final got = double.tryParse(m.group(3)!) ?? 0;
      final miss = double.tryParse(m.group(4)!) ?? 0;
      if (name.contains(':') || name.isEmpty) continue;
      final key = '$name|$req';
      if (seen.contains(key)) continue;
      if (req == totalRequired && got == totalEarned) continue;
      seen.add(key);
      categories.add(AcademicCategory(
        name: name,
        reqCredits: req,
        earnedCredits: got,
        missingCredits: miss,
      ));
    }

    return AcademicStatus(
      gpa: gpa,
      totalRequired: totalRequired,
      totalEarned: totalEarned,
      categories: categories,
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}
