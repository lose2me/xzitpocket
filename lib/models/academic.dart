import 'course.dart';

class LoginResult {
  final String? studentId;
  final String? studentName;
  final String? collegeName;
  final String? className;
  final String? majorName;
  final List<Course> courses;

  LoginResult({
    this.studentId,
    this.studentName,
    this.collegeName,
    this.className,
    this.majorName,
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
  final String courseCode;
  final String department;
  final String score;
  final double credit;
  final double gradePoint;
  final String type;
  final String category;
  final String teacher;
  final String examMethod;
  final String year;
  final String term;
  final String hours;
  final String maxScore;
  final String makeup;
  final String retake;
  final String suggestedYear;
  final String suggestedTerm;

  const GradeItem({
    required this.name,
    this.courseCode = '',
    this.department = '',
    required this.score,
    required this.credit,
    required this.gradePoint,
    required this.type,
    required this.category,
    required this.teacher,
    required this.examMethod,
    required this.year,
    required this.term,
    this.hours = '',
    this.maxScore = '',
    this.makeup = '',
    this.retake = '',
    this.suggestedYear = '',
    this.suggestedTerm = '',
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
          'courseCode': grade.courseCode,
          'department': grade.department,
          'score': grade.score,
          'credit': grade.credit,
          'gradePoint': grade.gradePoint,
          'type': grade.type,
          'category': grade.category,
          'teacher': grade.teacher,
          'examMethod': grade.examMethod,
          'year': grade.year,
          'term': grade.term,
          'hours': grade.hours,
          'maxScore': grade.maxScore,
          'makeup': grade.makeup,
          'retake': grade.retake,
          'suggestedYear': grade.suggestedYear,
          'suggestedTerm': grade.suggestedTerm,
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
          courseCode: '${raw['courseCode'] ?? ''}',
          department: '${raw['department'] ?? ''}',
          score: '${raw['score'] ?? ''}',
          credit: _asDouble(raw['credit']),
          gradePoint: _asDouble(raw['gradePoint']),
          type: '${raw['type'] ?? ''}',
          category: '${raw['category'] ?? ''}',
          teacher: '${raw['teacher'] ?? ''}',
          examMethod: '${raw['examMethod'] ?? ''}',
          year: '${raw['year'] ?? ''}',
          term: '${raw['term'] ?? ''}',
          hours: '${raw['hours'] ?? ''}',
          maxScore: '${raw['maxScore'] ?? ''}',
          makeup: '${raw['makeup'] ?? ''}',
          retake: '${raw['retake'] ?? ''}',
          suggestedYear: '${raw['suggestedYear'] ?? ''}',
          suggestedTerm: '${raw['suggestedTerm'] ?? ''}',
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
  final String sourceId;
  final List<AcademicCourse> courses;

  const AcademicCategory({
    required this.name,
    required this.reqCredits,
    required this.earnedCredits,
    required this.missingCredits,
    this.isDirectory = false,
    this.completed = false,
    this.children = const [],
    this.sourceId = '',
    this.courses = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'reqCredits': reqCredits,
    'earnedCredits': earnedCredits,
    'missingCredits': missingCredits,
    'isDirectory': isDirectory,
    'completed': completed,
    'children': [for (final child in children) child.toJson()],
    'sourceId': sourceId,
    'courses': [for (final course in courses) course.toJson()],
  };

  factory AcademicCategory.fromJson(Map<String, dynamic> json) =>
      AcademicCategory(
        name: '${json['name'] ?? ''}',
        reqCredits: _asDouble(json['reqCredits']),
        earnedCredits: _asDouble(json['earnedCredits']),
        missingCredits: _asDouble(json['missingCredits']),
        isDirectory: json['isDirectory'] == true,
        completed: json['completed'] == true,
        sourceId: '${json['sourceId'] ?? ''}',
        courses: [
          for (final raw in (json['courses'] as List<dynamic>? ?? const []))
            AcademicCourse.fromJson(raw as Map<String, dynamic>),
        ],
        children: [
          for (final raw in (json['children'] as List<dynamic>? ?? const []))
            AcademicCategory.fromJson(raw as Map<String, dynamic>),
        ],
      );

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

/// A course row returned by the academic-overview detail endpoint.
class AcademicCourse {
  final String studyStatus;
  final String academicYear;
  final String term;
  final String courseCode;
  final String name;
  final String hours;
  final String nature;
  final String credit;
  final String category;
  final String maxScore;
  final String gradePoint;
  final String score;
  final String makeup;
  final String retake;
  final String suggestedYear;
  final String suggestedTerm;
  final String importance;

  const AcademicCourse({
    this.studyStatus = '',
    this.academicYear = '',
    this.term = '',
    this.courseCode = '',
    this.name = '',
    this.hours = '',
    this.nature = '',
    this.credit = '',
    this.category = '',
    this.maxScore = '',
    this.gradePoint = '',
    this.score = '',
    this.makeup = '',
    this.retake = '',
    this.suggestedYear = '',
    this.suggestedTerm = '',
    this.importance = '',
  });

  Map<String, dynamic> toJson() => {
    'studyStatus': studyStatus,
    'academicYear': academicYear,
    'term': term,
    'courseCode': courseCode,
    'name': name,
    'hours': hours,
    'nature': nature,
    'credit': credit,
    'category': category,
    'maxScore': maxScore,
    'gradePoint': gradePoint,
    'score': score,
    'makeup': makeup,
    'retake': retake,
    'suggestedYear': suggestedYear,
    'suggestedTerm': suggestedTerm,
    'importance': importance,
  };

  factory AcademicCourse.fromJson(Map<String, dynamic> json) => AcademicCourse(
    studyStatus: '${json['studyStatus'] ?? ''}',
    academicYear: '${json['academicYear'] ?? ''}',
    term: '${json['term'] ?? ''}',
    courseCode: '${json['courseCode'] ?? ''}',
    name: '${json['name'] ?? ''}',
    hours: '${json['hours'] ?? ''}',
    nature: '${json['nature'] ?? ''}',
    credit: '${json['credit'] ?? ''}',
    category: '${json['category'] ?? ''}',
    maxScore: '${json['maxScore'] ?? ''}',
    gradePoint: '${json['gradePoint'] ?? ''}',
    score: '${json['score'] ?? ''}',
    makeup: '${json['makeup'] ?? ''}',
    retake: '${json['retake'] ?? ''}',
    suggestedYear: '${json['suggestedYear'] ?? ''}',
    suggestedTerm: '${json['suggestedTerm'] ?? ''}',
    importance: '${json['importance'] ?? ''}',
  );
}

class AcademicStatus {
  static const currentParserVersion = 3;

  final double gpa;
  final double totalRequired;
  final double totalEarned;
  final List<AcademicCategory> categories;
  final int parserVersion;

  const AcademicStatus({
    required this.gpa,
    required this.totalRequired,
    required this.totalEarned,
    required this.categories,
    this.parserVersion = currentParserVersion,
  });

  Map<String, dynamic> toJson() => {
    'gpa': gpa,
    'totalRequired': totalRequired,
    'totalEarned': totalEarned,
    'parserVersion': parserVersion,
    'categories': [for (final category in categories) category.toJson()],
  };

  factory AcademicStatus.fromJson(Map<String, dynamic> json) {
    if (json['parserVersion'] != currentParserVersion) {
      throw const FormatException('学业缓存版本无效');
    }
    final rawCategories = json['categories'];
    if (rawCategories is! List) {
      throw const FormatException('学业缓存分类格式无效');
    }
    return AcademicStatus(
      gpa: _asDouble(json['gpa']),
      totalRequired: _asDouble(json['totalRequired']),
      totalEarned: _asDouble(json['totalEarned']),
      categories: [
        for (final raw in rawCategories)
          AcademicCategory.fromJson(raw as Map<String, dynamic>),
      ],
    );
  }

  static double _asDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}
