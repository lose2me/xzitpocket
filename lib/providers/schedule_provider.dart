import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/semester_config.dart';
import '../models/course.dart';
import '../services/course_storage.dart';
import '../services/widget_service.dart';
import 'config_provider.dart';

final scheduleProvider =
    NotifierProvider<ScheduleNotifier, AsyncValue<List<Course>>>(
      ScheduleNotifier.new,
    );

class ScheduleNotifier extends Notifier<AsyncValue<List<Course>>> {
  late CourseStorage _storage;
  List<int> _hiveKeys = [];
  List<Course> _courses = [];
  List<Course> _originalCourses = [];

  @override
  AsyncValue<List<Course>> build() {
    _storage = ref.watch(courseStorageProvider);
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    _courses = courses;
    _originalCourses = _storage.getOriginalCourses();
    return AsyncValue.data(courses);
  }

  List<Course> get originalCourses => List.unmodifiable(_originalCourses);

  /// Returns the stable Hive key for the exact course instance shown by the UI.
  ///
  /// Conflict variants can reorder cards, so [sourceIndex] is only accepted
  /// when it still points to the same course instance; otherwise identity is
  /// used to avoid accidentally targeting a course with the same course ID.
  int? keyForCourse(Course course, {int? sourceIndex}) {
    if (sourceIndex != null &&
        sourceIndex >= 0 &&
        sourceIndex < _courses.length &&
        identical(_courses[sourceIndex], course)) {
      return _hiveKeys[sourceIndex];
    }
    for (var index = 0; index < _courses.length; index++) {
      if (identical(_courses[index], course)) return _hiveKeys[index];
    }
    return null;
  }

  Future<void> _reload() async {
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    _courses = courses;
    _originalCourses = _storage.getOriginalCourses();
    state = AsyncValue.data(courses);
    await _notifyWidget(courses);
  }

  Future<void> _notifyWidget(List<Course> courses) {
    return WidgetService.updateWidget(
      courses: courses,
      semesterStart: semesterStartDate,
    );
  }

  Future<void> updateFromLoginResult({
    required List<Course> courses,
    required String studentId,
    required String studentName,
    required String majorName,
    required String className,
  }) async {
    await ref
        .read(configProvider.notifier)
        .updateFromLogin(
          studentId: studentId,
          studentName: studentName,
          majorName: majorName,
          className: className,
        );
    if (_sameCourses(_courses, courses)) return;
    await _storage.saveCourses(courses);
    await _reload();
  }

  bool _sameCourses(List<Course> left, List<Course> right) {
    if (left.length != right.length) return false;
    final leftSignatures = left.map(_courseSignature).toList()..sort();
    final rightSignatures = right.map(_courseSignature).toList()..sort();
    return listEquals(leftSignatures, rightSignatures);
  }

  String _courseSignature(Course course) {
    final sessions = [...course.sessions]..sort();
    final weeks = [...course.weeks]..sort();
    return [
      course.title,
      course.teacher,
      course.weekday,
      sessions.join(','),
      weeks.join(','),
      course.campus,
      course.place,
      course.colorIndex,
      course.courseId,
    ].join('\u001f');
  }

  Future<void> addCourse(Course course) async {
    await _storage.addCourse(course);
    await _reload();
  }

  Future<void> updateCourse(int key, Course course) async {
    await _storage.updateCourse(key, course);
    await _reload();
  }

  Future<void> deleteCourseOccurrence(int key, int week) async {
    await _storage.deleteCourseOccurrence(key, week);
    await _reload();
  }

  Future<void> clearCourseDayOccurrence({
    required int weekday,
    required int week,
  }) async {
    await _storage.clearCourseDayOccurrence(weekday: weekday, week: week);
    await _reload();
  }

  Future<bool> restoreCourseDayOccurrence({
    required int weekday,
    required int week,
  }) async {
    final restored = await _storage.restoreCourseDayOccurrence(
      weekday: weekday,
      week: week,
    );
    if (restored) await _reload();
    return restored;
  }

  Future<void> moveCourseDayOccurrence({
    required int sourceWeekday,
    required int sourceWeek,
    required int targetWeekday,
    required int targetWeek,
  }) async {
    await _storage.moveCourseDayOccurrence(
      sourceWeekday: sourceWeekday,
      sourceWeek: sourceWeek,
      targetWeekday: targetWeekday,
      targetWeek: targetWeek,
    );
    await _reload();
  }

  Future<void> deleteCoursesByCourseId(String courseId) async {
    await _storage.deleteCoursesByCourseId(courseId);
    await _reload();
  }

  Future<void> syncCourseFields(
    String courseId, {
    required int excludeKey,
    String? title,
    String? teacher,
  }) async {
    await _storage.updateCoursesByCourseId(
      courseId,
      excludeKey: excludeKey,
      title: title,
      teacher: teacher,
    );
    await _reload();
  }

  Future<void> clearAll() async {
    await _storage.clearCourses();
    _hiveKeys = [];
    _courses = [];
    _originalCourses = [];
    state = const AsyncValue.data([]);
    await WidgetService.clearWidget();
  }
}
