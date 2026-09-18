import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/semester_config.dart';
import '../models/course.dart';
import '../services/course_storage.dart';
import '../services/widget_service.dart';
import '../services/control_service.dart';
import '../utils/course_adjustments.dart';
import 'app_settings_provider.dart';
import 'config_provider.dart';

final scheduleProvider =
    NotifierProvider<ScheduleNotifier, AsyncValue<List<Course>>>(
      ScheduleNotifier.new,
    );

class ScheduleNotifier extends Notifier<AsyncValue<List<Course>>> {
  late CourseStorage _storage;
  List<int> _hiveKeys = [];
  List<Course> _courses = [];

  @override
  AsyncValue<List<Course>> build() {
    _storage = ref.watch(courseStorageProvider);
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    _courses = courses;
    return AsyncValue.data(courses);
  }

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
    var adjustedCourses = courses;
    final settings = ref.read(appSettingsProvider);
    final local = parseCourseAdjustments(settings.courseAdjustmentsJson);
    final cloud = <String, String>{};
    if (settings.cloudCourseAdjustmentsEnabled) {
      try {
        final prefs = ref.read(preferencesStorageProvider);
        final versions = await ControlService.instance.fetchConfigVersions();
        final cachedJson = prefs.getCourseAdjustmentsCloudCache();
        if (cachedJson == null ||
            prefs.getCourseAdjustmentsCloudVersion() !=
                versions.courseAdjustments) {
          cloud.addAll(await ControlService.instance.fetchCourseAdjustments());
          await ref
              .read(appSettingsProvider.notifier)
              .setCloudCourseAdjustmentsJson(courseAdjustmentsToJson(cloud));
          await prefs.setCourseAdjustmentsCloudVersion(
            versions.courseAdjustments,
          );
        } else {
          cloud.addAll(parseCourseAdjustments(cachedJson));
        }
      } catch (_) {
        // Cloud adjustments are optional. Reuse the last valid response when
        // the control service is temporarily unavailable.
        cloud.addAll(
          parseCourseAdjustments(settings.cloudCourseAdjustmentsJson),
        );
      }
    }
    final merged = {...cloud, ...local};
    adjustedCourses = applyCourseAdjustments(courses, merged);
    if (_sameCourses(_courses, adjustedCourses)) return;
    await _storage.saveCourses(adjustedCourses);
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
    state = const AsyncValue.data([]);
    await WidgetService.clearWidget();
  }
}
