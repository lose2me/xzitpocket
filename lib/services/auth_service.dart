import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;

import '../constants/network_config.dart';
import '../constants/time_slots.dart';
import '../models/course.dart';
import '../models/book_list.dart';
import '../utils/course_text_parser.dart';
import '../utils/week_calculator.dart';
import 'cas_service.dart';

class LoginResult {
  final String? studentId;
  final String? studentName;
  final String? majorName;
  final String? className;
  final List<Course> courses;

  LoginResult({
    this.studentId,
    this.studentName,
    this.majorName,
    this.className,
    required this.courses,
  });
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

  Map<String, dynamic> toJson() => {
    'grades': [
      for (final grade in grades)
        {
          'name': grade.name,
          'score': grade.score,
          'credit': grade.credit,
          'gradePoint': grade.gradePoint,
          'type': grade.type,
          'category': grade.category,
          'teacher': grade.teacher,
          'examMethod': grade.examMethod,
          'year': grade.year,
          'term': grade.term,
        },
    ],
    'years': years,
    'termsByYear': termsByYear,
  };

  factory GradeResult.fromJson(Map<String, dynamic> json) => GradeResult(
    grades: [
      for (final raw in (json['grades'] as List<dynamic>? ?? const []))
        GradeItem(
          name: '${(raw as Map<String, dynamic>)['name'] ?? ''}',
          score: '${raw['score'] ?? ''}',
          credit: _asDouble(raw['credit']),
          gradePoint: _asDouble(raw['gradePoint']),
          type: '${raw['type'] ?? ''}',
          category: '${raw['category'] ?? ''}',
          teacher: '${raw['teacher'] ?? ''}',
          examMethod: '${raw['examMethod'] ?? ''}',
          year: '${raw['year'] ?? ''}',
          term: '${raw['term'] ?? ''}',
        ),
    ],
    years: [
      for (final value in (json['years'] as List<dynamic>? ?? const []))
        value.toString(),
    ],
    termsByYear: {
      for (final entry
          in (json['termsByYear'] as Map<String, dynamic>? ?? const {}).entries)
        entry.key: [
          for (final value in (entry.value as List<dynamic>? ?? const []))
            value.toString(),
        ],
    },
  );

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
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

  Map<String, dynamic> toJson() => {
    'name': name,
    'reqCredits': reqCredits,
    'earnedCredits': earnedCredits,
    'missingCredits': missingCredits,
    'isDirectory': isDirectory,
    'completed': completed,
    'children': [for (final child in children) child.toJson()],
  };

  factory AcademicCategory.fromJson(Map<String, dynamic> json) =>
      AcademicCategory(
        name: '${json['name'] ?? ''}',
        reqCredits: _asDouble(json['reqCredits']),
        earnedCredits: _asDouble(json['earnedCredits']),
        missingCredits: _asDouble(json['missingCredits']),
        isDirectory: json['isDirectory'] == true,
        completed: json['completed'] == true,
        children: [
          for (final raw in (json['children'] as List<dynamic>? ?? const []))
            AcademicCategory.fromJson(raw as Map<String, dynamic>),
        ],
      );

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
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

  Map<String, dynamic> toJson() => {
    'gpa': gpa,
    'totalRequired': totalRequired,
    'totalEarned': totalEarned,
    'categories': [for (final category in categories) category.toJson()],
  };

  factory AcademicStatus.fromJson(Map<String, dynamic> json) => AcademicStatus(
    gpa: _asDouble(json['gpa']),
    totalRequired: _asDouble(json['totalRequired']),
    totalEarned: _asDouble(json['totalEarned']),
    categories: [
      for (final raw in (json['categories'] as List<dynamic>? ?? const []))
        AcademicCategory.fromJson(raw as Map<String, dynamic>),
    ],
  );

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

BookListResult parseBookListPayload(dynamic payload) {
  if (payload is Map) {
    final rawItems = payload['items'] ?? payload['data'] ?? payload['rows'];
    if (rawItems is List) {
      return _bookListFromMaps(rawItems);
    }
  }
  if (payload is List) return _bookListFromMaps(payload);

  final source = payload?.toString() ?? '';
  if (source.trim().isEmpty) {
    return const BookListResult(items: []);
  }
  try {
    final decoded = jsonDecode(source);
    if (!identical(decoded, payload)) return parseBookListPayload(decoded);
  } catch (_) {
    // The endpoint normally returns HTML. Continue with table parsing.
  }

  final document = html_parser.parse(source);
  final candidates = document.querySelectorAll('table');
  html_dom.Element? selected;
  var selectedScore = 0;
  for (final table in candidates) {
    final rows = table.querySelectorAll('tr');
    final score = rows.fold<int>(0, (total, row) {
      final cells = row.querySelectorAll('th, td').length;
      return total + (cells >= 2 ? cells : 0);
    });
    if (score > selectedScore) {
      selected = table;
      selectedScore = score;
    }
  }
  final rows =
      selected?.querySelectorAll('tr') ?? document.querySelectorAll('tr');
  if (rows.isEmpty) {
    return const BookListResult(items: []);
  }

  final values = [
    for (final row in rows)
      [
        for (final cell in row.querySelectorAll('th, td'))
          _bookTableCellText(cell),
      ],
  ].where((row) => row.any((value) => value.isNotEmpty)).toList();
  if (values.isEmpty) {
    return const BookListResult(items: []);
  }

  final headerRow = values.first;
  final hasHeaderCells = rows.first.querySelectorAll('th').isNotEmpty;
  final columnCount = values.fold<int>(
    headerRow.length,
    (max, row) => row.length > max ? row.length : max,
  );
  final columns = hasHeaderCells
      ? [
          for (var index = 0; index < columnCount; index++)
            index < headerRow.length && headerRow[index].trim().isNotEmpty
                ? headerRow[index]
                : '字段 ${index + 1}',
        ]
      : [for (var index = 0; index < columnCount; index++) '字段 ${index + 1}'];
  final dataRows = hasHeaderCells ? values.skip(1) : values;
  return _bookListFromMaps([
    for (final row in dataRows)
      {
        for (var index = 0; index < columns.length; index++)
          columns[index]: index < row.length ? row[index] : '',
      },
  ]);
}

BookListSemesterCatalog buildBookListSemesterCatalog(
  GradeResult grades,
  String studentId,
) {
  final semesters = <String, BookListSemesterOption>{};
  for (final yearLabel in grades.years) {
    final academicYear = RegExp(r'20\d{2}').firstMatch(yearLabel)?.group(0);
    if (academicYear == null) continue;
    for (final termLabel in grades.termsByYear[yearLabel] ?? const <String>[]) {
      final term = _bookTermNumber(termLabel);
      if (term == null) continue;
      final option = _bookSemesterOption(int.parse(academicYear), term);
      semesters[option.key] = option;
    }
  }

  final historical = semesters.values.toList()..sort(_compareBookSemesters);
  final BookListSemesterOption? current;
  if (historical.isNotEmpty) {
    current = _nextBookSemester(historical.first);
  } else {
    final enrollmentYear = _studentEnrollmentYear(studentId);
    current = enrollmentYear == null
        ? null
        : _bookSemesterOption(enrollmentYear, 1);
  }
  if (current != null) semesters[current.key] = current;
  final options = semesters.values.toList()..sort(_compareBookSemesters);
  return BookListSemesterCatalog(options: options, current: current);
}

int? _bookTermNumber(String value) {
  final term = value.trim();
  if (term == '3' || term.contains('一')) return 1;
  if (term == '12' || term.contains('二')) return 2;
  final number = int.tryParse(term);
  return number == 1 || number == 2 ? number : null;
}

int? _studentEnrollmentYear(String studentId) {
  final value = studentId.trim();
  final fullYear = RegExp(r'^(20\d{2})').firstMatch(value)?.group(1);
  if (fullYear != null) return int.tryParse(fullYear);
  final shortYear = RegExp(r'^(\d{2})').firstMatch(value)?.group(1);
  final parsed = int.tryParse(shortYear ?? '');
  return parsed == null ? null : 2000 + parsed;
}

BookListSemesterOption _bookSemesterOption(int academicYear, int term) {
  final shortYear = (academicYear % 100).toString().padLeft(2, '0');
  return BookListSemesterOption(
    academicYear: academicYear.toString(),
    termCode: term == 1 ? '3' : '12',
    label: '$shortYear学年第$term学期',
  );
}

BookListSemesterOption _nextBookSemester(BookListSemesterOption latest) {
  final year = int.parse(latest.academicYear);
  return latest.termCode == '3'
      ? _bookSemesterOption(year, 2)
      : _bookSemesterOption(year + 1, 1);
}

int _compareBookSemesters(
  BookListSemesterOption left,
  BookListSemesterOption right,
) {
  final yearOrder = int.parse(right.academicYear)
      .compareTo(int.parse(left.academicYear));
  if (yearOrder != 0) return yearOrder;
  final leftTerm = left.termCode == '12' ? 2 : 1;
  final rightTerm = right.termCode == '12' ? 2 : 1;
  return rightTerm.compareTo(leftTerm);
}

BookListResult _bookListFromMaps(List<dynamic> rawItems) {
  final items = <BookListItem>[];
  for (final raw in rawItems) {
    if (raw is! Map) continue;
    final fields = <String, String>{
      for (final entry in raw.entries)
        _normalizeBookFieldName(entry.key.toString()):
            entry.value?.toString() ?? '',
    };
    final courseName = _cleanBookText(
      _firstBookField(fields, const ['kcmc', '课程名称', '课程']),
    );
    if (courseName.isEmpty) continue;
    final textbook = _firstBookField(fields, const ['jcxx', '教材信息', '教材']);
    for (final entry in _splitTextbookEntries(textbook)) {
      final parts = entry.split('/');
      final textbookName = parts.isEmpty ? '' : parts.first.trim();
      if (textbookName.isEmpty) continue;
      final tags = [
        for (final part in parts.skip(1))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      items.add(
        BookListItem(
          courseName: courseName,
          textbookName: textbookName,
          textbookTags: tags,
        ),
      );
    }
  }
  return BookListResult(items: items);
}

String _normalizeBookFieldName(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toLowerCase();

String _firstBookField(Map<String, String> fields, List<String> names) {
  for (final name in names) {
    final value = fields[_normalizeBookFieldName(name)] ?? '';
    if (value.trim().isNotEmpty) return value;
  }
  return '';
}

List<String> _splitTextbookEntries(String value) {
  final normalized = value
      .replaceAll(RegExp(r'&lt;br\s*/?&gt;', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');
  final entries = <String>[];
  for (final rawLine in normalized.split('\n')) {
    final line = _cleanBookText(rawLine);
    if (line.isEmpty) continue;

    // Some records put a second author after <br>, followed by the publisher
    // and edition. It is a continuation of the previous textbook, not a
    // textbook whose title is the author's name.
    if (entries.isNotEmpty &&
        _isTextbookAuthorContinuation(entries.last, line)) {
      entries[entries.length - 1] = '${entries.last}/$line';
    } else {
      entries.add(line);
    }
  }
  return entries;
}

bool _isTextbookAuthorContinuation(String previous, String current) {
  final previousParts = previous.split('/');
  final currentParts = current.split('/');
  if (previousParts.length != 2 || currentParts.length < 3) return false;
  if (!_looksLikeChinesePersonName(previousParts[1]) ||
      !_looksLikeChinesePersonName(currentParts.first)) {
    return false;
  }
  return currentParts
      .skip(1)
      .any((part) => part.contains('出版社') || part.contains('版'));
}

bool _looksLikeChinesePersonName(String value) {
  final text = value.trim();
  return RegExp(
    r'^[赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜戚谢邹喻柏水窦章云苏潘葛奚范彭郎鲁韦昌马苗凤花方俞任袁柳酆鲍史唐费廉岑薛雷贺倪汤滕殷罗毕郝邬安常乐于时傅皮卞齐康伍余元卜顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米贝明臧计伏成戴谈宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林刁钟徐邱骆高夏蔡田樊胡凌霍虞万支柯昝管卢莫经房裘缪干解应宗丁宣贲邓郁单杭洪包诸左石崔吉钮龚程嵇邢滑裴陆荣翁荀羊於惠甄曲家封芮羿储靳汲邴糜松井段富巫乌焦巴弓牧隗山谷车侯宓蓬全郗班仰秋仲伊宫宁仇栾暴甘钭厉戎祖武符刘景詹束龙叶幸司韶郜黎蓟薄印宿白怀蒲邰从鄂索咸籍赖卓蔺屠蒙池乔阴郁胥能苍双闻莘党翟谭贡劳逄姬申扶堵冉宰郦雍却璩桑桂濮牛寿通边扈燕冀郏浦尚农温别庄晏柴瞿阎充慕连茹习宦艾鱼容向古易慎戈廖庾终暨居衡步都耿满弘匡国文寇广禄阙东欧殳沃利蔚越夔隆师巩厍聂晁勾敖融冷訾辛阚那简饶空曾毋沙乜养鞠须丰巢关蒯相查后荆红游竺权逯盖益桓公万俟司马上官欧阳夏侯诸葛闻人东方赫连皇甫尉迟公羊澹台公冶宗政濮阳淳于单于太叔申屠公孙仲孙轩辕令狐钟离宇文长孙慕容鲜于闾丘司徒司空亓官司寇仉督子车颛孙端木巫马公西漆雕乐正壤驷公良拓跋夹谷宰父谷梁晋楚闫法汝鄢涂钦段干百里东郭南门呼延归海羊舌微生岳帅缑亢况后有琴梁丘左丘东门西门商牟佘佴伯赏南宫墨哈谯笪年爱阳佟第五言福][\u4e00-\u9fff]{1,4}(?:等|等人)?$',
  ).hasMatch(text);
}

String _bookTableCellText(html_dom.Element cell) {
  final source = cell.innerHtml.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  return (html_parser.parseFragment(source).text ?? '')
      .replaceAll('\u00a0', ' ')
      .trim();
}

String _cleanBookText(String value) =>
    value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

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

  Future<BookListPageResult> fetchBookListPage(
    String studentId,
    String password,
  ) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      final grades = await _fetchGrades(session.dio);
      final catalog = buildBookListSemesterCatalog(grades, studentId);
      final selected = catalog.current;
      if (catalog.options.isEmpty || selected == null) {
        throw AuthException('未获取到可查询的书单学期');
      }
      final books = await _fetchBookList(
        session.dio,
        academicYear: selected.academicYear,
        termCode: selected.termCode,
      );
      return BookListPageResult(
        semesters: catalog.options,
        selectedSemester: selected,
        books: books,
      );
    } finally {
      session.close();
    }
  }

  Future<BookListResult> fetchBookList(
    String studentId,
    String password, {
    required String academicYear,
    required String termCode,
  }) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      return await _fetchBookList(
        session.dio,
        academicYear: academicYear,
        termCode: termCode,
      );
    } finally {
      session.close();
    }
  }

  Future<(LoginResult, ExamResult?, GradeResult?, AcademicStatus?)>
  loginAndFetchAll(
    String studentId,
    String password, {
    bool fetchExams = true,
    bool fetchGrades = true,
    bool fetchAcademic = true,
  }) async {
    final session = await _casService.loginJw(studentId, password);
    try {
      final results = await Future.wait<Object?>([
        _fetchSchedule(session.dio),
        fetchExams ? _fetchExams(session.dio) : Future<ExamResult?>.value(null),
        fetchGrades
            ? _fetchGrades(session.dio)
            : Future<GradeResult?>.value(null),
        fetchAcademic
            ? _fetchAcademicStatus(session.dio)
            : Future<AcademicStatus?>.value(null),
      ]);
      return (
        results[0] as LoginResult,
        results[1] as ExamResult?,
        results[2] as GradeResult?,
        results[3] as AcademicStatus?,
      );
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
      studentId: xsxx['XH']?.toString().trim(),
      studentName: xsxx['XM']?.toString().trim(),
      majorName: xsxx['ZYMC']?.toString().trim(),
      className: xsxx['BJMC']?.toString().trim(),
      courses: courses,
    );
  }

  Future<BookListResult> _fetchBookList(
    Dio dio, {
    required String academicYear,
    required String termCode,
  }) async {
    final response = await dio.get(
      '$jwBaseUrl/xsxk/tjxkyzb_cxXkResultTjxkYzb.html?doType=query',
      queryParameters: {
        'xkxnm': academicYear,
        'xkxqm': termCode,
        'queryModel.showCount': '1500',
        'queryModel.currentPage': '1',
        'queryModel.sortName': '',
        'queryModel.sortOrder': 'asc',
        'time': '0',
      },
      options: Options(responseType: ResponseType.json),
    );
    final payload = response.data;
    if (payload is String && payload.contains('用户登录')) {
      throw AuthException('会话已过期');
    }
    return parseBookListPayload(payload);
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
