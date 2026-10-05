import 'dart:ui';

class Course {
  final String title;
  final String teacher;
  final int weekday;
  final List<int> sessions;
  final List<int> weeks;
  final String campus;
  final String place;
  final int colorIndex;
  final String courseId;

  Course({
    required this.title,
    required this.teacher,
    required this.weekday,
    required this.sessions,
    required this.weeks,
    required this.campus,
    required this.place,
    required this.colorIndex,
    this.courseId = '',
  });

  /// Stable, storage-independent representation used by configuration
  /// backup files.  Hive's binary representation is intentionally not exposed
  /// outside the app.
  Map<String, dynamic> toJson() => {
    'title': title,
    'teacher': teacher,
    'weekday': weekday,
    'sessions': sessions,
    'weeks': weeks,
    'campus': campus,
    'place': place,
    'colorIndex': colorIndex,
    'courseId': courseId,
  };

  factory Course.fromJson(Map<String, dynamic> json) {
    List<int> readInts(String key) {
      final value = json[key];
      if (value is! List) {
        throw FormatException('课程字段 $key 不是数组');
      }
      return value.map((item) {
        if (item is int) return item;
        final parsed = int.tryParse(item.toString());
        if (parsed == null) throw FormatException('课程字段 $key 含有无效数字');
        return parsed;
      }).toList();
    }

    String readString(String key) {
      final value = json[key];
      if (value == null) return '';
      if (value is! String) throw FormatException('课程字段 $key 不是文字');
      return value;
    }
    final weekday = int.tryParse(json['weekday']?.toString() ?? '');
    final colorIndex = int.tryParse(json['colorIndex']?.toString() ?? '');
    if (readString('title').trim().isEmpty || weekday == null ||
        weekday < 1 || weekday > 7 || colorIndex == null) {
      throw const FormatException('课程字段无效');
    }
    final sessions = readInts('sessions');
    final weeks = readInts('weeks');
    if (sessions.isEmpty || sessions.any((session) => session < 1 || session > 14)) {
      throw const FormatException('课程节次须在 1～14 节之间');
    }
    if (weeks.isEmpty || weeks.any((week) => week < 1 || week > 104)) {
      throw const FormatException('课程周次须在 1～104 周之间');
    }
    return Course(
      title: readString('title'),
      teacher: readString('teacher'),
      weekday: weekday,
      sessions: sessions,
      weeks: weeks,
      campus: readString('campus'),
      place: readString('place'),
      colorIndex: colorIndex,
      courseId: readString('courseId'),
    );
  }

  int get startSession =>
      sessions.isEmpty ? 1 : sessions.reduce((a, b) => a < b ? a : b);
  int get endSession =>
      sessions.isEmpty ? 1 : sessions.reduce((a, b) => a > b ? a : b);
  int get sessionSpan => endSession - startSession + 1;

  bool isInWeek(int week) => weeks.contains(week);

  Course copyWith({
    String? title,
    String? teacher,
    int? weekday,
    List<int>? sessions,
    List<int>? weeks,
    String? campus,
    String? place,
    int? colorIndex,
    String? courseId,
  }) {
    return Course(
      title: title ?? this.title,
      teacher: teacher ?? this.teacher,
      weekday: weekday ?? this.weekday,
      sessions: sessions ?? this.sessions,
      weeks: weeks ?? this.weeks,
      campus: campus ?? this.campus,
      place: place ?? this.place,
      colorIndex: colorIndex ?? this.colorIndex,
      courseId: courseId ?? this.courseId,
    );
  }

  static const List<Color> colors = [
    Color(0xFFF8D2D7),
    Color(0xFFD2E5F8),
    Color(0xFFD2F0E5),
    Color(0xFFF8F3D2),
    Color(0xFFE5D2F8),
    Color(0xFFF8E5D2),
    Color(0xFFF2C6D0),
    Color(0xFFC6E0F2),
    Color(0xFFC6F2E0),
    Color(0xFFF2F0C6),
    Color(0xFFE0C6F2),
    Color(0xFFF2E0C6),
    Color(0xFFEBBFC9),
    Color(0xFFBFD8EB),
    Color(0xFFBFEBDC),
    Color(0xFFEBE8BF),
    Color(0xFFD8BFEB),
    Color(0xFFEBD8BF),
    Color(0xFFF6D9DF),
    Color(0xFFD9EAF6),
    Color(0xFFD9F6EC),
    Color(0xFFF6F4D9),
    Color(0xFFEAD9F6),
    Color(0xFFF6EAD9),
  ];

  Color get color {
    if (colorIndex >= 0 && colorIndex < colors.length) {
      return colors[colorIndex];
    }
    return Color(colorIndex);
  }
}
