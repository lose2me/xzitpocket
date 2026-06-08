import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/semester_config.dart';
import '../models/course.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'config_provider.dart';

final scheduleProvider =
    NotifierProvider<ScheduleNotifier, AsyncValue<List<Course>>>(
      ScheduleNotifier.new,
    );

class ScheduleNotifier extends Notifier<AsyncValue<List<Course>>> {
  late StorageService _storage;
  List<int> _hiveKeys = [];

  @override
  AsyncValue<List<Course>> build() {
    _storage = ref.watch(storageServiceProvider);
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    return AsyncValue.data(courses);
  }

  int keyAt(int index) => _hiveKeys[index];

  Future<void> _reload() async {
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    state = AsyncValue.data(courses);
    await _notifyWidget(courses);
  }

  Future<void> _notifyWidget(List<Course> courses) {
    return WidgetService.updateWidget(
      courses: courses,
      semesterStart: semesterStartDate,
      semesterTotalWeeks: semesterTotalWeeks,
    );
  }

  Future<void> updateFromLoginResult({
    required List<Course> courses,
    required String studentId,
    required String studentName,
  }) async {
    await _storage.saveCourses(courses);
    await ref
        .read(configProvider.notifier)
        .updateFromLogin(studentId: studentId, studentName: studentName);
    await _reload();
  }

  Future<void> addCourse(Course course) async {
    await _storage.addCourse(course);
    await _reload();
  }

  Future<void> updateCourse(int key, Course course) async {
    await _storage.updateCourse(key, course);
    await _reload();
  }

  Future<void> deleteCourse(int key) async {
    await _storage.deleteCourse(key);
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
    state = const AsyncValue.data([]);
    await WidgetService.clearWidget();
  }
}

class _SimpleNotifier<T> extends Notifier<T> {
  final T _initial;
  _SimpleNotifier(this._initial);

  @override
  T build() => _initial;

  void set(T value) => state = value;
}

final selectedWeekProvider = NotifierProvider<_SimpleNotifier<int>, int>(
  () => _SimpleNotifier(1),
);

final showNonCurrentWeekCoursesProvider =
    NotifierProvider<_SimpleNotifier<bool>, bool>(
      () => _SimpleNotifier(false),
    );
