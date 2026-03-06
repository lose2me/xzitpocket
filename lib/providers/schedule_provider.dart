import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  ScheduleNotifier(this._storage, this._ref)
      : super(const AsyncValue.loading()) {
    _loadFromCache();
  }

  void _loadFromCache() {
    final cached = _storage.getCourses();
    state = AsyncValue.data(cached);
  }

  void _notifyWidget(List<Course> courses) {
    WidgetService.updateWidget(
      courses: courses,
      semesterStart: semesterStartDate,
    );
  }

  /// 用登录结果直接更新课表
  Future<void> updateFromLoginResult({
    required List<Course> courses,
    required String studentId,
    required String studentName,
  }) async {
    await _storage.saveCourses(courses);
    _ref.read(configProvider.notifier).updateFromLogin(
          studentId: studentId,
          studentName: studentName,
        );
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void addCourse(Course course) {
    _storage.addCourse(course);
    final courses = _storage.getCourses();
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void updateCourse(int index, Course course) {
    _storage.updateCourseAt(index, course);
    final courses = _storage.getCourses();
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void deleteCourse(int index) {
    _storage.deleteCourseAt(index);
    final courses = _storage.getCourses();
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void syncCourseFields(
    String courseId,
    int excludeIndex, {
    String? title,
    String? teacher,
    String? place,
    List<int>? weeks,
  }) {
    _storage.updateCoursesByCourseId(
      courseId,
      excludeIndex: excludeIndex,
      title: title,
      teacher: teacher,
      place: place,
      weeks: weeks,
    );
    final courses = _storage.getCourses();
    state = AsyncValue.data(courses);
    _notifyWidget(courses);
  }

  void clearAll() {
    _storage.clearCourses();
    state = const AsyncValue.data([]);
    _notifyWidget([]);
  }
}

/// Currently selected week for display.
final selectedWeekProvider = StateProvider<int>((ref) => 1);
