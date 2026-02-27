/// Calculates the current week number given [semesterStart].
/// Returns 0 if the semester hasn't started yet.
int currentWeek(DateTime semesterStart) {
  final now = DateTime.now();
  final diff = now.difference(DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ));
  if (diff.isNegative) return 0;
  return (diff.inDays ~/ 7) + 1;
}

/// Returns the date range (Mon–Sun) for the given [week] relative to
/// [semesterStart].
(DateTime, DateTime) weekDateRange(DateTime semesterStart, int week) {
  // semesterStart is assumed to be a Monday.
  final monday = DateTime(
    semesterStart.year,
    semesterStart.month,
    semesterStart.day,
  ).add(Duration(days: (week - 1) * 7));
  final sunday = monday.add(const Duration(days: 6));
  return (monday, sunday);
}

/// Returns the weekday dates (Mon–Sun) for the given [week].
List<DateTime> weekDates(DateTime semesterStart, int week) {
  final (monday, _) = weekDateRange(semesterStart, week);
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

/// Auto-detect current school term: (year, termIndex).
/// Sep-Dec -> (currentYear, 1); Jan-Aug -> (currentYear-1, 2).
(int, int) getCurrentSchoolTerm() {
  final now = DateTime.now();
  if (now.month >= 9 && now.month <= 12) {
    return (now.year, 1);
  }
  return (now.year - 1, 2);
}
