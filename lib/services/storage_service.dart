import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import '../models/course.g.dart';

const _courseBoxName = 'courses';

class StorageService {
  late Box<Course> _courseBox;
  late SharedPreferences _prefs;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(CourseAdapter());
    _courseBox = await Hive.openBox<Course>(_courseBoxName);
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Course storage ──

  List<Course> getCourses() => _courseBox.values.toList();

  /// Returns parallel lists of Hive keys and courses.
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
    String? place,
    List<int>? weeks,
  }) async {
    final map = _courseBox.toMap();
    for (final entry in map.entries) {
      final key = entry.key as int;
      if (key == excludeKey) continue;
      final c = entry.value;
      if (c.courseId == courseId) {
        await _courseBox.put(
          key,
          c.copyWith(
            title: title,
            teacher: teacher,
            place: place,
            weeks: weeks,
          ),
        );
      }
    }
  }

  Future<void> clearCourses() async {
    await _courseBox.clear();
  }

  // ── Config (SharedPreferences) ──

  String? getStudentId() => _prefs.getString('student_id');
  Future<void> setStudentId(String id) => _prefs.setString('student_id', id);

  String? getStudentName() => _prefs.getString('student_name');
  Future<void> setStudentName(String name) =>
      _prefs.setString('student_name', name);

  String? getSavedPassword() => _prefs.getString('saved_password');
  Future<void> setSavedPassword(String pwd) =>
      _prefs.setString('saved_password', pwd);

  Future<void> clearCredentials() async {
    await _prefs.remove('student_id');
    await _prefs.remove('student_name');
    await _prefs.remove('saved_password');
  }

  bool get isLoggedIn => getStudentId() != null && getStudentName() != null;
}
