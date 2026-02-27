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

  Future<void> saveCourses(List<Course> courses) async {
    await _courseBox.clear();
    for (final c in courses) {
      await _courseBox.add(c);
    }
  }

  Future<void> addCourse(Course course) async {
    await _courseBox.add(course);
  }

  Future<void> updateCourseAt(int index, Course course) async {
    await _courseBox.putAt(index, course);
  }

  Future<void> deleteCourseAt(int index) async {
    await _courseBox.deleteAt(index);
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
