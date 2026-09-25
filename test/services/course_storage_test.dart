import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/models/school_calendar.dart';
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

  test('covers a day with every repeated and overlapping course', () async {
    await storage.clearCourses();
    await storage.addCourse(
      _course(
        title: '源课程一',
        weekday: 1,
        weeks: const [1, 2],
        sessions: const [1, 2],
        courseId: 'SRC-1',
      ),
    );
    await storage.addCourse(
      _course(
        title: '源课程二',
        weekday: 1,
        weeks: const [1],
        sessions: const [1, 2],
        courseId: 'SRC-2',
      ),
    );
    await storage.addCourse(
      _course(
        title: '目标旧课',
        weekday: 3,
        weeks: const [1, 2],
        courseId: 'DST-1',
      ),
    );

    await storage.moveCourseDayOccurrence(
      sourceWeekday: 1,
      sourceWeek: 1,
      targetWeekday: 3,
      targetWeek: 1,
    );

    final courses = storage.getCourses();
    expect(
      courses.where((course) => course.weekday == 3 && course.isInWeek(1)),
      hasLength(2),
    );
    expect(
      courses
          .where((course) => course.weekday == 3 && course.isInWeek(1))
          .map((course) => course.title),
      containsAll(['源课程一', '源课程二']),
    );
    expect(courses.singleWhere((course) => course.title == '目标旧课').weeks, [2]);
    expect(
      courses.where(
        (course) =>
            course.title == '源课程一' && course.weekday == 1 && course.isInWeek(1),
      ),
      isEmpty,
    );
  });

  test('clears only the selected week from a whole day', () async {
    await storage.clearCourses();
    await storage.addCourse(
      _course(title: '周一课程', weekday: 1, weeks: const [1, 2]),
    );

    await storage.clearCourseDayOccurrence(weekday: 1, week: 1);

    expect(storage.getCourses().single.weeks, [2]);
  });

  test('restores a day from the original timetable snapshot', () async {
    await storage.clearCourses();
    final original = _course(title: '原始周一课程', weekday: 1, weeks: const [1, 2]);
    await storage.saveCourses([original]);
    await storage.clearCourseDayOccurrence(weekday: 1, week: 1);

    expect(
      await storage.restoreCourseDayOccurrence(weekday: 1, week: 1),
      isTrue,
    );
    expect(storage.getCourses().single.title, '原始周一课程');
    expect(storage.getCourses().single.weeks, [1, 2]);
  });

  test(
    'applies calendar adjustments from the original snapshot without chaining',
    () async {
      await storage.clearCourses();
      final source = _course(
        title: '原始周三课程',
        weekday: 3,
        weeks: const [1],
        courseId: 'WED-1',
      );
      final oldTarget = _course(
        title: '原始周二课程',
        weekday: 2,
        weeks: const [1],
        courseId: 'TUE-1',
      );
      await storage.saveCourses([source, oldTarget]);

      final start = DateTime(2026, 8, 31);
      final days = [
        for (var i = 0; i < 7; i++)
          SchoolDay(
            date: start.add(Duration(days: i)),
            weekday: i + 1,
            holiday: false,
            adjustment: i == 1 ? '20260902' : (i == 2 ? '/' : null),
          ),
      ];
      expect(
        await storage.applyCloudAdjustments(days: days, semesterStart: start),
        isTrue,
      );

      final courses = storage.getCourses();
      expect(
        courses
            .where((course) => course.weekday == 2 && course.isInWeek(1))
            .map((course) => course.title),
        ['原始周三课程'],
      );
      expect(
        courses.where((course) => course.weekday == 3 && course.isInWeek(1)),
        isEmpty,
      );
    },
  );
}

Course _course({
  required String title,
  required int weekday,
  List<int> weeks = const [1, 2],
  String courseId = 'MATH-1',
  List<int> sessions = const [1, 2],
}) {
  return Course(
    title: title,
    teacher: '张老师',
    weekday: weekday,
    sessions: sessions,
    weeks: weeks,
    campus: '中心校区',
    place: '教学楼101',
    colorIndex: 0,
    courseId: courseId,
  );
}
