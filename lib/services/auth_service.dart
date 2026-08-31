import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

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

  /// 是否为目录节点（该成绩项下有子级，页面行内为可折叠标题）。
  final bool isDirectory;

  /// 是否已通过（页面 sftg='1'）。
  final bool completed;

  /// 子级项（树形层级，最多 4 级）。叶节点为空列表。
  final List<AcademicCategory> children;

  const AcademicCategory({
    required this.name,
    required this.reqCredits,
    required this.earnedCredits,
    required this.missingCredits,
    this.isDirectory = false,
    this.completed = false,
    this.children = const [],
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

      final weeks = parseWeekRanges(c['zcd']?.toString() ?? '');
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
        creditStr = credit == credit.toInt()
            ? credit.toInt().toString()
            : '$credit';
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

      grades.add(
        GradeItem(
          name: (i['kcmc'] ?? '') as String,
          score: '${i['cj'] ?? ''}',
          credit: (credit is num)
              ? credit.toDouble()
              : double.tryParse('$credit') ?? 0,
          gradePoint: (jd is num) ? jd.toDouble() : double.tryParse('$jd') ?? 0,
          type: (i['kcxzmc'] ?? '') as String,
          category: (i['kclbmc'] ?? '') as String,
          teacher: (i['jsxm'] ?? '') as String,
          examMethod: (i['khfsmc'] ?? '') as String,
          year: year,
          term: term,
        ),
      );
    }

    final years = yearSet.toList()..sort((a, b) => b.compareTo(a));
    final termsMap = termsByYear.map((k, v) => MapEntry(k, v.toList()..sort()));

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
    final gpaText = _stripHtml(body);
    final gpa =
        double.tryParse(
          gpaMatch?.group(1) ??
              RegExp(r'GPA）?：?\s*([\d.]+)').firstMatch(gpaText)?.group(1) ??
              '',
        ) ??
        0;

    final totalMatch = RegExp(
      r"title1[^>]*>[^<]*<br\s*/?>\s*最低毕业学分[：:]([\d.]+).*?已获得总学分[：:]([\d.]+)",
    ).firstMatch(body);
    final totalText = _stripHtml(body);
    final totalTextMatch = RegExp(
      r'最低毕业学分\s*[：:]?\s*([\d.]+).*?已获得总学分\s*[：:]?\s*([\d.]+)',
      dotAll: true,
    ).firstMatch(totalText);
    final totalRequired =
        double.tryParse(
          totalMatch?.group(1) ?? totalTextMatch?.group(1) ?? '',
        ) ??
        0;
    final totalEarned =
        double.tryParse(
          totalMatch?.group(2) ?? totalTextMatch?.group(2) ?? '',
        ) ??
        0;

    // The template embeds these tags in JavaScript on some deployments and
    // emits real HTML on others. Parse tag attributes independently of quote
    // style; `liX` and `pX` share the same X identifier.
    final parents = <String, String>{};
    final liPattern = RegExp(r'<li\b[^>]*>', caseSensitive: false);
    for (final match in liPattern.allMatches(body)) {
      final attrs = _parseAcademicAttributes(match.group(0)!);
      final id = _academicId(attrs['id'], 'li');
      if (id == null) continue;
      parents[id] = _academicParentId(attrs['fxfyqjd_id']);
    }

    final byId = <String, AcademicCategory>{};
    final pPattern = RegExp(r'<p\b[^>]*>', caseSensitive: false);
    for (final match in pPattern.allMatches(body)) {
      final attrs = _parseAcademicAttributes(match.group(0)!);
      final classes = attrs['class']?.split(RegExp(r'\s+')) ?? const <String>[];
      if (!classes.any((value) => value.toLowerCase() == 'title1')) continue;
      final id = _academicId(attrs['id'], 'p');
      if (id == null || !parents.containsKey(id)) continue;
      final close = body.indexOf('</p', match.end);
      final rawContent = body.substring(
        match.end,
        close < 0 ? body.length : close,
      );
      final name = _academicName(rawContent);
      if (name.isEmpty) continue;
      final yxxf = double.tryParse(attrs['yxxf'] ?? '') ?? 0;
      final yqzdxf = double.tryParse(attrs['yqzdxf'] ?? '') ?? 0;
      byId[id] = AcademicCategory(
        name: name,
        reqCredits: yqzdxf,
        earnedCredits: yxxf,
        missingCredits: (yqzdxf - yxxf).clamp(0.0, double.infinity).toDouble(),
        completed: attrs['sftg'] == '1',
      );
    }

    if (byId.isEmpty) {
      final legacy = _parseLegacyAcademicCategories(
        body,
        totalRequired: totalRequired,
        totalEarned: totalEarned,
      );
      if (legacy.isNotEmpty) {
        return AcademicStatus(
          gpa: gpa,
          totalRequired: totalRequired,
          totalEarned: totalEarned,
          categories: legacy,
        );
      }
    }

    // Some versions emit a p before its li. Keep only nodes with a valid
    // matching li, then rebuild the hierarchy from the parent identifiers.
    final childrenIds = <String, List<String>>{};
    final rootIds = <String>[];
    for (final id in byId.keys) {
      final parentId = parents[id] ?? '';
      if (parentId.isNotEmpty && byId.containsKey(parentId)) {
        childrenIds.putIfAbsent(parentId, () => []).add(id);
      } else {
        rootIds.add(id);
      }
    }

    AcademicCategory buildTree(String id, Set<String> path) {
      final node = byId[id]!;
      // A malformed server response must not recurse forever.
      if (!path.add(id)) return node;
      final kids = (childrenIds[id] ?? const <String>[])
          .map((childId) => buildTree(childId, {...path}))
          .where((k) => !_ignoredAcademicNames.contains(k.name))
          .toList();
      return AcademicCategory(
        name: node.name,
        reqCredits: node.reqCredits,
        earnedCredits: node.earnedCredits,
        missingCredits: node.missingCredits,
        isDirectory: kids.isNotEmpty,
        completed: node.completed,
        children: kids,
      );
    }

    var categories = rootIds
        .map((id) => buildTree(id, <String>{}))
        .where((c) => !_ignoredAcademicNames.contains(c.name))
        .toList();

    // If the server adds one transparent wrapper (for example, a major),
    // present its actual categories at the top level.
    if (categories.length == 1 && categories.first.children.isNotEmpty) {
      categories = categories.first.children;
    }

    return AcademicStatus(
      gpa: gpa,
      totalRequired: totalRequired,
      totalEarned: totalEarned,
      categories: categories,
    );
  }

  static String? _academicId(String? raw, String prefix) {
    if (raw == null ||
        !raw.toLowerCase().startsWith(prefix.toLowerCase()) ||
        raw.length == prefix.length) {
      return null;
    }
    final id = raw.substring(prefix.length);
    return RegExp(r'^[A-Za-z0-9]+$').hasMatch(id) ? id : null;
  }

  static String _academicParentId(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.startsWith('li') && value.length > 2) return value.substring(2);
    if (value.startsWith('p') && value.length > 1) return value.substring(1);
    return value;
  }

  static String _academicName(String markup) {
    final firstPart = markup
        .split(RegExp(r'&nbsp;|&#160;|\u00a0', caseSensitive: false))
        .first;
    final fragment = html_parser.parseFragment('<span>$firstPart</span>');
    final element = fragment.querySelector('span');
    if (element == null) return _cleanAcademicName(firstPart);

    final text = StringBuffer();
    bool append(html_dom.Node node) {
      if (node is html_dom.Element && node.localName == 'br') return false;
      if (node is html_dom.Text) {
        text.write(node.text);
      } else if (node is html_dom.Element) {
        for (final child in node.nodes) {
          if (!append(child)) return false;
        }
      }
      return true;
    }

    for (final node in element.nodes) {
      if (!append(node)) break;
    }
    return _cleanAcademicName(text.toString());
  }

  static Map<String, String> _parseAcademicAttributes(String tag) {
    final attributes = <String, String>{};
    final pattern = RegExp(
      r'''([A-Za-z_:][A-Za-z0-9_.:-]*)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',
    );
    for (final match in pattern.allMatches(tag)) {
      final key = match.group(1)!.toLowerCase();
      attributes[key] =
          match.group(2) ?? match.group(3) ?? match.group(4) ?? '';
    }
    return attributes;
  }

  static List<AcademicCategory> _parseLegacyAcademicCategories(
    String body, {
    required double totalRequired,
    required double totalEarned,
  }) {
    final pattern = RegExp(
      r'"([^"\r\n]+?)&nbsp;"[^:]+yqxf[^:]+:([\d.]+)[^:]+hdxf[^:]+:([\d.]+)[^:]+whdxf[^:]+:([\d.]+)',
    );
    final seen = <String>{};
    final categories = <AcademicCategory>[];
    for (final match in pattern.allMatches(body)) {
      final name = match.group(1)!.trim();
      final req = double.tryParse(match.group(2)!) ?? 0;
      final earned = double.tryParse(match.group(3)!) ?? 0;
      final missing = double.tryParse(match.group(4)!) ?? 0;
      if (name.isEmpty || name.contains(':')) continue;
      if (req == totalRequired && earned == totalEarned) continue;
      if (!_ignoredAcademicNames.contains(name) && seen.add('$name|$req')) {
        categories.add(
          AcademicCategory(
            name: name,
            reqCredits: req,
            earnedCredits: earned,
            missingCredits: missing,
          ),
        );
      }
    }
    return categories;
  }

  static String _stripHtml(String value) => value
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll(RegExp(r'\\[rn]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _cleanAcademicName(String value) {
    var cleaned = value.replaceAll('\u00a0', ' ').trim();
    // A few server templates concatenate the label as `"foo" + "bar"`.
    cleaned = cleaned.replaceAll(RegExp(r'''["']\s*\+\s*["']'''), '');
    cleaned = cleaned.replaceAll('" +', '').replaceAll("' +", '');
    cleaned = cleaned.replaceAll('"', '').replaceAll("'", '').trim();
    return cleaned;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    return int.tryParse(value.toString());
  }
}

/// 学业总览树里不展示的分类名称。
const _ignoredAcademicNames = {'其他课程', '创新创业情况'};
