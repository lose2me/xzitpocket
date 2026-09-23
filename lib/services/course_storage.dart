import 'package:hive_flutter/hive_flutter.dart';

import '../models/course.dart';
import '../models/course.g.dart';

const _courseBoxName = 'courses';
const _originalCourseBoxName = 'courses_original';

class CourseStorage {
  late Box<Course> _courseBox;
  late Box<Course> _originalCourseBox;

  Future<void> init({String? path}) async {
    if (path == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(path);
    }
    if (!Hive.isAdapterRegistered(CourseAdapter().typeId)) {
      Hive.registerAdapter(CourseAdapter());
    }
    _courseBox = await Hive.openBox<Course>(_courseBoxName);
    _originalCourseBox = await Hive.openBox<Course>(_originalCourseBoxName);
  }

  List<Course> getCourses() => _courseBox.values.toList();

  List<Course> getOriginalCourses() => _originalCourseBox.values.toList();

  (List<int> keys, List<Course> courses) getCoursesWithKeys() {
    final keys = <int>[];
    final courses = <Course>[];
    for (final entry in _courseBox.toMap().entries) {
      keys.add(entry.key as int);
      courses.add(entry.value);
    }
    return (keys, courses);
  }

  Future<void> saveCourses(List<Course> courses) async {
    await _originalCourseBox.clear();
    for (final c in courses) {
      await _originalCourseBox.add(c);
    }
    await _courseBox.clear();
    for (final c in courses) {
      await _courseBox.add(c);
    }
  }

  /// Restores one local day/week from the last successful教务系统 snapshot.
  /// Returns false when no snapshot has been saved yet.
  Future<bool> restoreCourseDayOccurrence({
    required int weekday,
    required int week,
  }) async {
    final original = _originalCourseBox.values
        .where(
          (course) => course.weekday == weekday && course.weeks.contains(week),
        )
        .toList();
    if (_originalCourseBox.isEmpty) return false;

    await clearCourseDayOccurrence(weekday: weekday, week: week);
    for (final source in original) {
      MapEntry<dynamic, Course>? existing;
      for (final entry in _courseBox.toMap().entries) {
        if (entry.value.weekday == weekday &&
            _sameCourseExceptWeekAndWeekday(entry.value, source)) {
          existing = entry;
          break;
        }
      }
      if (existing != null) {
        final weeks = {...existing.value.weeks, week}.toList()..sort();
        await _courseBox.put(
          existing.key,
          existing.value.copyWith(weeks: weeks),
        );
      } else {
        await _courseBox.add(source.copyWith(weeks: [week]));
      }
    }
    return true;
  }

  Future<void> addCourse(Course course) async {
    await _courseBox.add(course);
  }

  Future<void> updateCourse(int key, Course course) async {
    await _courseBox.put(key, course);
  }

  /// Removes one occurrence of a recurring course from [week].
  ///
  /// A course may be scheduled in multiple weeks. Keep the record (and its
  /// stable key) while other weeks remain; only remove it completely when the
  /// selected week was its last occurrence.
  Future<void> deleteCourseOccurrence(int key, int week) async {
    final course = _courseBox.get(key);
    if (course == null || !course.weeks.contains(week)) return;

    final remainingWeeks = course.weeks
        .where((value) => value != week)
        .toList();
    if (remainingWeeks.isEmpty) {
      await _courseBox.delete(key);
    } else {
      await _courseBox.put(key, course.copyWith(weeks: remainingWeeks));
    }
  }

  /// Clears every course occurrence on [weekday] in one [week]. Other weeks
  /// remain on the original records, matching the existing single-delete
  /// semantics.
  Future<void> clearCourseDayOccurrence({
    required int weekday,
    required int week,
  }) async {
    final updates = <int, Course>{};
    final deletes = <int>[];
    for (final entry in _courseBox.toMap().entries) {
      final key = entry.key as int;
      final course = entry.value;
      if (course.weekday != weekday || !course.weeks.contains(week)) continue;
      final remainingWeeks = course.weeks
          .where((value) => value != week)
          .toList();
      if (remainingWeeks.isEmpty) {
        deletes.add(key);
      } else {
        updates[key] = course.copyWith(weeks: remainingWeeks);
      }
    }
    if (deletes.isNotEmpty) await _courseBox.deleteAll(deletes);
    if (updates.isNotEmpty) await _courseBox.putAll(updates);
  }

  /// Moves every course occurrence from one day to another. The destination
  /// occurrence is cleared first, then the source occurrence is cleared, and
  /// every overlapping/repeated source course is recreated at the target.
  Future<void> moveCourseDayOccurrence({
    required int sourceWeekday,
    required int sourceWeek,
    required int targetWeekday,
    required int targetWeek,
  }) async {
    if (sourceWeekday == targetWeekday && sourceWeek == targetWeek) return;

    final entries = _courseBox.toMap().map(
      (key, value) => MapEntry(key as int, value),
    );
    final sources = entries.values
        .where(
          (course) =>
              course.weekday == sourceWeekday &&
              course.weeks.contains(sourceWeek),
        )
        .toList();
    final updates = <int, Course>{};
    final deletes = <int>[];

    for (final entry in entries.entries) {
      final course = entry.value;
      if (course.weekday != targetWeekday ||
          !course.weeks.contains(targetWeek)) {
        continue;
      }
      final remainingWeeks = course.weeks
          .where((value) => value != targetWeek)
          .toList();
      if (remainingWeeks.isEmpty) {
        deletes.add(entry.key);
      } else {
        updates[entry.key] = course.copyWith(weeks: remainingWeeks);
      }
    }

    if (deletes.isNotEmpty) await _courseBox.deleteAll(deletes);
    if (updates.isNotEmpty) await _courseBox.putAll(updates);

    // The source snapshot was taken before either side was cleared, so all
    // repeated and conflicting courses are retained for the move.
    final sourceEntries = _courseBox.toMap().map(
      (key, value) => MapEntry(key as int, value),
    );
    final sourceUpdates = <int, Course>{};
    final sourceDeletes = <int>[];
    for (final entry in sourceEntries.entries) {
      final course = entry.value;
      if (course.weekday != sourceWeekday ||
          !course.weeks.contains(sourceWeek)) {
        continue;
      }
      final remainingWeeks = course.weeks
          .where((value) => value != sourceWeek)
          .toList();
      if (remainingWeeks.isEmpty) {
        sourceDeletes.add(entry.key);
      } else {
        sourceUpdates[entry.key] = course.copyWith(weeks: remainingWeeks);
      }
    }
    if (sourceDeletes.isNotEmpty) await _courseBox.deleteAll(sourceDeletes);
    if (sourceUpdates.isNotEmpty) await _courseBox.putAll(sourceUpdates);

    // Reuse an equivalent target record where possible so repeated cover
    // operations do not create a new Hive record for every week.
    final remaining = _courseBox.toMap().map(
      (key, value) => MapEntry(key as int, value),
    );
    for (final source in sources) {
      MapEntry<int, Course>? match;
      for (final entry in remaining.entries) {
        if (entry.value.weekday == targetWeekday &&
            _sameCourseExceptWeekAndWeekday(entry.value, source)) {
          match = entry;
          break;
        }
      }
      if (match != null) {
        final weeks = {...match.value.weeks, targetWeek}.toList()..sort();
        final updated = match.value.copyWith(weeks: weeks);
        await _courseBox.put(match.key, updated);
        remaining[match.key] = updated;
      } else {
        final copy = source.copyWith(
          weekday: targetWeekday,
          weeks: [targetWeek],
        );
        final key = await _courseBox.add(copy);
        remaining[key] = copy;
      }
    }
  }

  bool _sameCourseExceptWeekAndWeekday(Course left, Course right) =>
      left.title == right.title &&
      left.teacher == right.teacher &&
      left.sessions.length == right.sessions.length &&
      _sameIntList(left.sessions, right.sessions) &&
      left.campus == right.campus &&
      left.place == right.place &&
      left.colorIndex == right.colorIndex &&
      left.courseId == right.courseId;

  bool _sameIntList(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Future<void> deleteCoursesByCourseId(String courseId) async {
    final normalized = courseId.trim();
    if (normalized.isEmpty) return;
    final keys = [
      for (final entry in _courseBox.toMap().entries)
        if (entry.value.courseId.trim() == normalized) entry.key,
    ];
    if (keys.isNotEmpty) await _courseBox.deleteAll(keys);
  }

  Future<void> updateCoursesByCourseId(
    String courseId, {
    required int excludeKey,
    String? title,
    String? teacher,
  }) async {
    final map = _courseBox.toMap();
    for (final entry in map.entries) {
      final key = entry.key as int;
      if (key == excludeKey) continue;
      final c = entry.value;
      if (c.courseId == courseId) {
        await _courseBox.put(key, c.copyWith(title: title, teacher: teacher));
      }
    }
  }

  Future<void> clearCourses() async {
    await _courseBox.clear();
    await _originalCourseBox.clear();
  }
}
