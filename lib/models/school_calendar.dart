import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 校历信息：一学期的每日标记。
///
/// The bundled snapshot is used as an offline fallback. A validated calendar
/// downloaded from xzitpocket-control can replace the global instance at
/// startup without requiring an app release each semester.
class SchoolDay {
  final DateTime date;
  final int weekday; // 1=周一 … 7=周日
  final bool holiday; // 是否放假（周末 + 标注的节假日）
  final String? festival; // 特殊节日名（如 国庆），无则 null

  const SchoolDay({
    required this.date,
    required this.weekday,
    required this.holiday,
    this.festival,
  });

  Map<String, dynamic> toJson() => {
    'date':
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    'weekday': weekday,
    'holiday': holiday,
    'festival': festival,
  };

  factory SchoolDay.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date']?.toString() ?? '';
    final match = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$')
        .firstMatch(rawDate.trim());
    if (match == null) {
      throw const FormatException('校历日期格式无效');
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const FormatException('校历日期格式无效');
    }
    final weekday = (json['weekday'] as num?)?.toInt() ?? date.weekday;
    if (weekday < 1 || weekday > 7 || weekday != date.weekday) {
      throw const FormatException('校历星期格式无效');
    }
    final holiday = json['holiday'];
    if (holiday is! bool) throw const FormatException('校历假期标记无效');
    final rawFestival = json['festival'];
    final festival = rawFestival == null || rawFestival == false
        ? null
        : rawFestival.toString().trim();
    return SchoolDay(
      date: date,
      weekday: weekday,
      holiday: holiday,
      festival: festival == null || festival.isEmpty ? null : festival,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SchoolDay &&
      other.date == date &&
      other.weekday == weekday &&
      other.holiday == holiday &&
      other.festival == festival;

  @override
  int get hashCode => Object.hash(date, weekday, holiday, festival);
}

/// 每日原始数据：(年, 月, 日, 星期几, 放假, 节日)。
const List<(int, int, int, int, bool, String?)> _rawDays = [
  (2026, 8, 31, 1, false, null),
  (2026, 9, 1, 2, false, null),
  (2026, 9, 2, 3, false, null),
  (2026, 9, 3, 4, false, null),
  (2026, 9, 4, 5, false, null),
  (2026, 9, 5, 6, true, null),
  (2026, 9, 6, 7, true, null),
  (2026, 9, 7, 1, false, null),
  (2026, 9, 8, 2, false, null),
  (2026, 9, 9, 3, false, null),
  (2026, 9, 10, 4, false, null),
  (2026, 9, 11, 5, false, null),
  (2026, 9, 12, 6, true, null),
  (2026, 9, 13, 7, true, null),
  (2026, 9, 14, 1, false, null),
  (2026, 9, 15, 2, false, null),
  (2026, 9, 16, 3, false, null),
  (2026, 9, 17, 4, false, null),
  (2026, 9, 18, 5, false, null),
  (2026, 9, 19, 6, true, null),
  (2026, 9, 20, 7, true, null),
  (2026, 9, 21, 1, false, null),
  (2026, 9, 22, 2, false, null),
  (2026, 9, 23, 3, false, null),
  (2026, 9, 24, 4, false, null),
  (2026, 9, 25, 5, true, '中秋'),
  (2026, 9, 26, 6, true, null),
  (2026, 9, 27, 7, true, null),
  (2026, 9, 28, 1, false, null),
  (2026, 9, 29, 2, false, null),
  (2026, 9, 30, 3, false, null),
  (2026, 10, 1, 4, true, '国庆'),
  (2026, 10, 2, 5, true, null),
  (2026, 10, 3, 6, true, null),
  (2026, 10, 4, 7, true, null),
  (2026, 10, 5, 1, true, null),
  (2026, 10, 6, 2, true, null),
  (2026, 10, 7, 3, true, null),
  (2026, 10, 8, 4, false, null),
  (2026, 10, 9, 5, false, null),
  (2026, 10, 10, 6, true, null),
  (2026, 10, 11, 7, true, null),
  (2026, 10, 12, 1, false, null),
  (2026, 10, 13, 2, false, null),
  (2026, 10, 14, 3, false, null),
  (2026, 10, 15, 4, false, null),
  (2026, 10, 16, 5, false, null),
  (2026, 10, 17, 6, true, null),
  (2026, 10, 18, 7, true, null),
  (2026, 10, 19, 1, false, null),
  (2026, 10, 20, 2, false, null),
  (2026, 10, 21, 3, false, null),
  (2026, 10, 22, 4, false, null),
  (2026, 10, 23, 5, false, null),
  (2026, 10, 24, 6, true, null),
  (2026, 10, 25, 7, true, null),
  (2026, 10, 26, 1, false, null),
  (2026, 10, 27, 2, false, null),
  (2026, 10, 28, 3, false, null),
  (2026, 10, 29, 4, false, null),
  (2026, 10, 30, 5, false, null),
  (2026, 10, 31, 6, true, null),
  (2026, 11, 1, 7, true, null),
  (2026, 11, 2, 1, false, null),
  (2026, 11, 3, 2, false, null),
  (2026, 11, 4, 3, false, null),
  (2026, 11, 5, 4, false, null),
  (2026, 11, 6, 5, false, null),
  (2026, 11, 7, 6, true, null),
  (2026, 11, 8, 7, true, null),
  (2026, 11, 9, 1, false, null),
  (2026, 11, 10, 2, false, null),
  (2026, 11, 11, 3, false, null),
  (2026, 11, 12, 4, false, null),
  (2026, 11, 13, 5, false, null),
  (2026, 11, 14, 6, true, null),
  (2026, 11, 15, 7, true, null),
  (2026, 11, 16, 1, false, null),
  (2026, 11, 17, 2, false, null),
  (2026, 11, 18, 3, false, null),
  (2026, 11, 19, 4, false, null),
  (2026, 11, 20, 5, false, null),
  (2026, 11, 21, 6, true, null),
  (2026, 11, 22, 7, true, null),
  (2026, 11, 23, 1, false, null),
  (2026, 11, 24, 2, false, null),
  (2026, 11, 25, 3, false, null),
  (2026, 11, 26, 4, false, null),
  (2026, 11, 27, 5, false, null),
  (2026, 11, 28, 6, true, null),
  (2026, 11, 29, 7, true, null),
  (2026, 11, 30, 1, false, null),
  (2026, 12, 1, 2, false, null),
  (2026, 12, 2, 3, false, null),
  (2026, 12, 3, 4, false, null),
  (2026, 12, 4, 5, false, null),
  (2026, 12, 5, 6, true, null),
  (2026, 12, 6, 7, true, null),
  (2026, 12, 7, 1, false, null),
  (2026, 12, 8, 2, false, null),
  (2026, 12, 9, 3, false, null),
  (2026, 12, 10, 4, false, null),
  (2026, 12, 11, 5, false, null),
  (2026, 12, 12, 6, true, null),
  (2026, 12, 13, 7, true, null),
  (2026, 12, 14, 1, false, null),
  (2026, 12, 15, 2, false, null),
  (2026, 12, 16, 3, false, null),
  (2026, 12, 17, 4, false, null),
  (2026, 12, 18, 5, false, null),
  (2026, 12, 19, 6, true, null),
  (2026, 12, 20, 7, true, null),
  (2026, 12, 21, 1, false, null),
  (2026, 12, 22, 2, false, null),
  (2026, 12, 23, 3, false, null),
  (2026, 12, 24, 4, false, null),
  (2026, 12, 25, 5, false, null),
  (2026, 12, 26, 6, true, null),
  (2026, 12, 27, 7, true, null),
  (2026, 12, 28, 1, false, null),
  (2026, 12, 29, 2, false, null),
  (2026, 12, 30, 3, false, null),
  (2026, 12, 31, 4, false, null),
  (2027, 1, 1, 5, true, '元旦'),
  (2027, 1, 2, 6, true, null),
  (2027, 1, 3, 7, true, null),
  (2027, 1, 4, 1, false, null),
  (2027, 1, 5, 2, false, null),
  (2027, 1, 6, 3, false, null),
  (2027, 1, 7, 4, false, null),
  (2027, 1, 8, 5, false, null),
  (2027, 1, 9, 6, true, null),
  (2027, 1, 10, 7, true, null),
];

/// 构建每日校历信息。
List<SchoolDay> schoolCalendarDays() => [
  for (final (y, m, d, wd, holiday, festival) in _rawDays)
    SchoolDay(
      date: DateTime(y, m, d),
      weekday: wd,
      holiday: holiday,
      festival: festival,
    ),
];

/// 基于校历数据的学期日历：提供周号、周区间、该周假期等查询。
class SemesterCalendar extends ChangeNotifier {
  static final _fallbackStart = DateTime(2026, 8, 31);
  static final _fallbackEnd = DateTime(2027, 1, 10);

  List<SchoolDay> _days;

  SemesterCalendar(List<SchoolDay> days) : _days = _sortedDays(days);

  List<SchoolDay> get days => List.unmodifiable(_days);

  DateTime get start =>
      _days.isEmpty ? _fallbackStart : _mondayOf(_days.first.date);

  DateTime get end => _days.isEmpty ? _fallbackEnd : _dateOnly(_days.last.date);

  /// Replaces the active calendar while preserving the global instance used by
  /// timetable, school-calendar and widget consumers.
  void replaceDays(Iterable<SchoolDay> days) {
    final sorted = _sortedDays(days);
    if (listEquals(_days, sorted)) return;
    _days = sorted;
    notifyListeners();
  }

  /// 学期实际开学日，即校历数据中的第一天。
  ///
  /// [start] 是用于周号计算的第 1 周周一；当校历第一天不是周一时，
  /// 两者会不同。需要向教务系统或小组件传递学期起点时，应使用此属性。
  DateTime get semesterStartDate =>
      days.isEmpty ? start : _dateOnly(days.first.date);

  /// 学期总周数（第 1 周 = 从 start 起的 7 天段）。
  int get totalWeeks =>
      days.isEmpty ? 0 : ((end.difference(start).inDays) ~/ 7) + 1;

  /// [date] 在第几周；未开学返回 0。
  int weekOf(DateTime date) {
    final diff = _dateOnly(date).difference(start).inDays;
    if (diff < 0) return 0;
    return (diff ~/ 7) + 1;
  }

  /// 第 [week] 周的周一~周日。
  (DateTime, DateTime) weekRange(int week) {
    final monday = start.add(Duration(days: (week - 1) * 7));
    return (monday, monday.add(const Duration(days: 6)));
  }

  /// The seven dates in the given week, Monday through Sunday.
  List<DateTime> weekDates(int week) {
    final (monday, _) = weekRange(week);
    return List.generate(7, (index) => monday.add(Duration(days: index)));
  }

  /// 第 [week] 周的所有日。
  List<SchoolDay> daysOfWeek(int week) {
    final (monday, sunday) = weekRange(week);
    return days
        .where((d) => !d.date.isBefore(monday) && !d.date.isAfter(sunday))
        .toList();
  }

  /// 第 [week] 周内的特殊节日名（去重）。
  List<String> festivalNamesInWeek(int week) {
    final seen = <String>{};
    for (final d in daysOfWeek(week)) {
      if (d.festival != null) seen.add(d.festival!);
    }
    return seen.toList();
  }

  bool get hasStarted => weekOf(DateTime.now()) > 0;
}

List<SchoolDay> _sortedDays(Iterable<SchoolDay> days) {
  final result = List<SchoolDay>.from(days);
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

/// Decodes the control-service calendar payload. The payload may be either a
/// bare list or an object containing a `days` list for compatibility.
List<SchoolDay> schoolCalendarDaysFromJson(String source) {
  final decoded = jsonDecode(source);
  final raw = decoded is List
      ? decoded
      : decoded is Map
      ? decoded['days']
      : null;
  if (raw is! List || raw.isEmpty) {
    throw const FormatException('校历数据为空');
  }
  final days = [
    for (final item in raw)
      if (item is Map) SchoolDay.fromJson(item.cast<String, dynamic>()),
  ];
  if (days.length != raw.length) {
    throw const FormatException('校历数据格式无效');
  }
  final sorted = _sortedDays(days);
  for (var index = 1; index < sorted.length; index++) {
    if (sorted[index].date.difference(sorted[index - 1].date).inDays != 1) {
      throw const FormatException('校历日期必须连续且不能重复');
    }
  }
  return sorted;
}

String schoolCalendarDaysToJson(Iterable<SchoolDay> days) =>
    jsonEncode([for (final day in _sortedDays(days)) day.toJson()]);

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _mondayOf(DateTime value) {
  final date = _dateOnly(value);
  return date.subtract(Duration(days: date.weekday - 1));
}

/// 全局学期日历（默认从内置校历数据构建，可由控制端覆盖）。
final SemesterCalendar semesterCalendar = SemesterCalendar(
  schoolCalendarDays(),
);
