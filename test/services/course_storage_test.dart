import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/providers/config_provider.dart';
import 'package:xzitpocket/providers/schedule_provider.dart';
import 'package:xzitpocket/services/course_storage.dart';

void main() {
  late Directory directory;
  late CourseStorage storage;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('xzitpocket_courses_');
    storage = CourseStorage();
    await storage.init(path: directory.path);
  });

  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('single deletion removes only the selected week occurrence', () async {
    final first = _course(title: '高等数学（一）', weekday: 1, weeks: const [1, 2, 3]);
    final second = _course(title: '高等数学（二）', weekday: 3, weeks: const [1, 2]);
    final unrelated = _course(title: '大学英语', weekday: 5, courseId: 'ENGLISH-1');
    await storage.addCourse(first);
    await storage.addCourse(second);
    await storage.addCourse(unrelated);

    final (keys, courses) = storage.getCoursesWithKeys();
    expect(courses, hasLength(3));

    final container = ProviderContainer(
      overrides: [courseStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final visibleCourses = container.read(scheduleProvider).requireValue;
    final secondKey = container
        .read(scheduleProvider.notifier)
        .keyForCourse(visibleCourses[1]);
    expect(secondKey, keys[1]);

    await storage.deleteCourseOccurrence(secondKey!, 2);
    expect(storage.getCourses().map((course) => course.title), [
      '高等数学（一）',
      '高等数学（二）',
      '大学英语',
    ]);
    expect(storage.getCourses()[1].weeks, [1]);

    final firstKey = storage.getCoursesWithKeys().$1.first;
    await storage.deleteCourseOccurrence(firstKey, 2);
    expect(storage.getCourses().first.weeks, [1, 3]);

    await storage.deleteCoursesByCourseId('MATH-1');
    expect(storage.getCourses().map((course) => course.title), ['大学英语']);
  });
}

Course _course({
  required String title,
  required int weekday,
  List<int> weeks = const [1, 2],
  String courseId = 'MATH-1',
}) {
  return Course(
    title: title,
    teacher: '张老师',
    weekday: weekday,
    sessions: const [1, 2],
    weeks: weeks,
    campus: '中心校区',
    place: '教学楼101',
    colorIndex: 0,
    courseId: courseId,
  );
}
