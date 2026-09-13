import 'package:hive_flutter/hive_flutter.dart';

import '../models/course.dart';
import '../models/course.g.dart';

const _courseBoxName = 'courses';

class CourseStorage {
  late Box<Course> _courseBox;

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
  }

  List<Course> getCourses() => _courseBox.values.toList();

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
    await _courseBox.clear();
    for (final c in courses) {
      await _courseBox.add(c);
    }
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
  }
}
