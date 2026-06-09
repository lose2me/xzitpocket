import 'package:hive_flutter/hive_flutter.dart';

import '../models/course.dart';
import '../models/course.g.dart';

const _courseBoxName = 'courses';

class CourseStorage {
  late Box<Course> _courseBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CourseAdapter());
    _courseBox = await Hive.openBox<Course>(_courseBoxName);
  }

  List<Course> getCourses() => _courseBox.values.toList();

  (List<int> keys, List<Course> courses) getCoursesWithKeys() {
    final map = _courseBox.toMap();
    final keys = map.keys.cast<int>().toList();
    final courses = map.values.toList();
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

  Future<void> deleteCourse(int key) async {
    await _courseBox.delete(key);
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
