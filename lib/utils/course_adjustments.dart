import 'dart:convert';

import '../models/course.dart';
import '../models/school_calendar.dart';

/// Parses a target-date to original-date course adjustment map. An empty value
/// means that the target date should be cleared. Invalid entries are ignored so
/// a malformed optional client configuration never prevents OA login.
Map<String, String> parseCourseAdjustments(String? source) {
  if (source == null || source.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(source);
    final raw = decoded is Map && decoded['adjustments'] is Map
        ? decoded['adjustments']
        : decoded;
    if (raw is! Map) return const {};
    final result = <String, String>{};
    for (final entry in raw.entries) {
      final target = entry.key.toString().trim();
      final source = entry.value.toString().trim();
      if (_isCompactDate(target) &&
          (source.isEmpty || _isCompactDate(source))) {
        result[target] = source;
      }
    }
    return result;
  } catch (_) {
    return const {};
  }
}

bool _isCompactDate(String value) {
  if (!RegExp(r'^\d{8}$').hasMatch(value)) return false;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(4, 6));
  final day = int.parse(value.substring(6, 8));
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

String courseAdjustmentsToJson(Map<String, String> adjustments) =>
    const JsonEncoder.withIndent('  ').convert(
      Map.fromEntries(
        adjustments.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
      ),
    );

/// Applies mappings to the original occurrences in [courses]. The map is
/// target date → original source date. A target is first cleared, then the
/// source occurrences from the original snapshot are written to it. Source
/// dates remain unchanged, and mappings never read already-adjusted results.
List<Course> applyCourseAdjustments(
  List<Course> courses,
  Map<String, String> adjustments,
) {
  if (adjustments.isEmpty) return courses;
  final originalByDate = <String, List<_CourseOccurrence>>{};
  for (var courseIndex = 0; courseIndex < courses.length; courseIndex++) {
    final course = courses[courseIndex];
    for (final originalWeek in course.weeks) {
      final date = _occurrenceDate(originalWeek, course.weekday);
      if (date == null) continue;
      final key = _compactDate(date);
      (originalByDate[key] ??= <_CourseOccurrence>[]).add(
        _CourseOccurrence(courseIndex, course, date),
      );
    }
  }

  final targetDates = <String>{
    ...originalByDate.keys,
    ...adjustments.keys,
  }.toList()..sort();
  final adjusted = <_AdjustedOccurrence>[];
  for (final targetKey in targetDates) {
    final sourceKey = adjustments[targetKey];
    final sourceOccurrences = sourceKey == null
        ? originalByDate[targetKey]
        : sourceKey.isEmpty
        ? const <_CourseOccurrence>[]
        : originalByDate[sourceKey] ?? const <_CourseOccurrence>[];
    for (final occurrence in sourceOccurrences ?? const <_CourseOccurrence>[]) {
      final targetDate = _parseCompactDate(targetKey);
      if (targetDate != null) {
        adjusted.add(_AdjustedOccurrence(occurrence, targetDate));
      }
    }
  }

  final grouped = <String, List<int>>{};
  final groupedCourses = <String, Course>{};
  final groupedWeekdays = <String, int>{};
  for (final occurrence in adjusted) {
    final targetWeek = semesterCalendar.weekOf(occurrence.targetDate);
    if (targetWeek <= 0) continue;
    final key =
        '${occurrence.original.courseIndex}:${occurrence.targetDate.weekday}';
    (grouped[key] ??= <int>[]).add(targetWeek);
    groupedCourses[key] = occurrence.original.course;
    groupedWeekdays[key] = occurrence.targetDate.weekday;
  }
  return [
    for (final entry in grouped.entries)
      groupedCourses[entry.key]!.copyWith(
        weekday: groupedWeekdays[entry.key],
        weeks: entry.value.toSet().toList()..sort(),
      ),
  ];
}

class _CourseOccurrence {
  final int courseIndex;
  final Course course;
  final DateTime date;

  const _CourseOccurrence(this.courseIndex, this.course, this.date);
}

class _AdjustedOccurrence {
  final _CourseOccurrence original;
  final DateTime targetDate;

  const _AdjustedOccurrence(this.original, this.targetDate);
}

DateTime? _occurrenceDate(int week, int weekday) {
  if (week < 1 || weekday < 1 || weekday > 7) return null;
  final (monday, _) = semesterCalendar.weekRange(week);
  return monday.add(Duration(days: weekday - 1));
}

DateTime? _parseCompactDate(String value) {
  if (!_isCompactDate(value)) return null;
  return DateTime(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(4, 6)),
    int.parse(value.substring(6, 8)),
  );
}

String _compactDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
