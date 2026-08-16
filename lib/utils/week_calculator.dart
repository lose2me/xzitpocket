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

/// Auto-detect current school term: (year, termIndex).
/// 第一学期 (term=1): 2月-8月 (春季学期, 含暑假)
/// 第二学期 (term=2): 9月-次年2月 (秋季学期, 跨年: 9-12月当年, 1月属上学年)
(int, int) getCurrentSchoolTerm({DateTime? reference}) {
  final now = reference ?? DateTime.now();
  if (now.month >= 2 && now.month <= 8) {
    return (now.year, 1);
  }
  if (now.month >= 9 && now.month <= 12) {
    return (now.year, 2);
  }
  // 1月 → 上学年第二学期
  return (now.year - 1, 2);
}

DateTime _normalizeDate(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
