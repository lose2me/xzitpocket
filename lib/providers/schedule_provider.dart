import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/semester_config.dart';
import '../models/course.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'config_provider.dart';

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, AsyncValue<List<Course>>>((ref) {
      final storage = ref.watch(storageServiceProvider);
      return ScheduleNotifier(storage, ref);
    });

class ScheduleNotifier extends StateNotifier<AsyncValue<List<Course>>> {
  final StorageService _storage;
  final Ref _ref;
  List<int> _hiveKeys = [];

  ScheduleNotifier(this._storage, this._ref)
    : super(const AsyncValue.loading()) {
    _loadFromCache();
  }

  /// Convert a positional index (from the UI list) to the stable Hive key.
  int keyAt(int index) => _hiveKeys[index];

  void _loadFromCache() {
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    state = AsyncValue.data(courses);
  }

  void _reload() {
    final (keys, courses) = _storage.getCoursesWithKeys();
    _hiveKeys = keys;
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void _notifyWidget(List<Course> courses) {
    WidgetService.updateWidget(
      courses: courses,
      semesterStart: semesterStartDate,
      semesterTotalWeeks: semesterTotalWeeks,
    );
  }

  /// 用登录结果直接更新课表
  Future<void> updateFromLoginResult({
    required List<Course> courses,
    required String studentId,
    required String studentName,
  }) async {
    await _storage.saveCourses(courses);
    await _ref
        .read(configProvider.notifier)
        .updateFromLogin(studentId: studentId, studentName: studentName);
    _reload();
  }

  Future<void> addCourse(Course course) async {
    await _storage.addCourse(course);
    _reload();
  }

  Future<void> updateCourse(int key, Course course) async {
    await _storage.updateCourse(key, course);
    _reload();
  }

  Future<void> deleteCourse(int key) async {
    await _storage.deleteCourse(key);
    _reload();
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
    _reload();
  }

  Future<void> clearAll() async {
    await _storage.clearCourses();
    _hiveKeys = [];
    state = const AsyncValue.data([]);
    await WidgetService.clearWidget();
  }
}

/// Currently selected week for display.
final selectedWeekProvider = StateProvider<int>((ref) => 1);

/// Whether to show courses that do not belong to the selected week.
final showNonCurrentWeekCoursesProvider = StateProvider<bool>((ref) => false);
