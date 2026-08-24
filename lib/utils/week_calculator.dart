import '../constants/semester_config.dart';

/// Returns the Monday of the week that contains [date].
DateTime _mondayOfWeek(DateTime date) {
  return _normalizeDate(date).subtract(Duration(days: date.weekday - 1));
}

/// Calculates the current week number given [semesterStart].
/// Week 1 starts on the Monday of the week containing [semesterStart],
/// so [semesterStart] does not need to be a Monday.
/// Returns 0 if the semester hasn't started yet.
int currentWeek(DateTime semesterStart, {DateTime? reference}) {
  final now = _normalizeDate(reference ?? DateTime.now());
  final startMonday = _mondayOfWeek(semesterStart);
  final diff = now.difference(startMonday);
  if (diff.isNegative) return 0;
  return (diff.inDays ~/ 7) + 1;
}

/// Returns the date range (Mon–Sun) for the given [week].
/// Week 1 covers the Monday of the week containing [semesterStart]
/// through the following Sunday.
(DateTime, DateTime) weekDateRange(DateTime semesterStart, int week) {
  final monday = _mondayOfWeek(semesterStart)
      .add(Duration(days: (week - 1) * 7));
  final sunday = monday.add(const Duration(days: 6));
  return (monday, sunday);
}

/// Returns the weekday dates (Mon–Sun) for the given [week].
List<DateTime> weekDates(DateTime semesterStart, int week) {
  final (monday, _) = weekDateRange(semesterStart, week);
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

/// Determine school term to query from the configured semester start date.
///
/// Follows zfsoft (正方教务) semantics: the academic year starts in autumn.
///   fall 期（term=1, xqm=3）: 8月/9月开学 ~ 次年1月   例如 2026-08-31 -> (2026, 1)
///   spring 期（term=2, xqm=12）: 2月/3月开学 ~ 7月   例如 2026-03-01 -> (2025, 2)
///
/// The term is derived from [semesterStart] (defaults to the app's configured
/// [semesterStartDate]), so the timetable queries the semester the user picked,
/// not the one inferred from today's date.
(int, int) getCurrentSchoolTerm({DateTime? semesterStart}) {
  final start = semesterStart ?? semesterStartDate;
  // 8 月及以后开学 -> 秋季学期，学年 = 开学年份。
  // 校历的首日可能落在 8 月最后一周（例如 8 月 31 日）。
  if (start.month >= 8) {
    return (start.year, 1);
  }
  // 1-7 月开学 -> 春季学期，属于上一学年（学年从去年 8 月开始）。
  return (start.year - 1, 2);
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
