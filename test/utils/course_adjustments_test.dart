import 'package:flutter_test/flutter_test.dart';

import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/utils/course_adjustments.dart';

void main() {
  test('overwrites a target with the original source snapshot', () {
    final adjusted = applyCourseAdjustments(
      [_course('周二课', 2, 1), _course('周三课', 3, 2), _course('周四课', 4, 3)],
      // Week 3 is 2026-09-15 (Tue), 2026-09-16 (Wed), 2026-09-17 (Thu).
      {'20260916': '20260917'},
    );
    expect(
      adjusted.map((item) => '${item.title}:${item.weekday}'),
      containsAll(<String>['周二课:2', '周四课:3', '周四课:4']),
    );
    expect(adjusted.where((item) => item.title == '周三课'), isEmpty);
  });

  test('empty source clears the target date', () {
    final adjusted = applyCourseAdjustments(
      [_course('周四课', 4, 3)],
      {'20260917': ''},
    );
    expect(adjusted, isEmpty);
  });

  test('multiple overrides use only the original snapshot', () {
    final adjusted = applyCourseAdjustments(
      [_course('周三课', 3, 2), _course('周四课', 4, 3), _course('周五课', 5, 4)],
      {'20260916': '20260917', '20260917': '20260918'},
    );
    expect(
      adjusted.map((item) => '${item.title}:${item.weekday}'),
      containsAll(<String>['周四课:3', '周五课:4', '周五课:5']),
    );
    expect(adjusted.where((item) => item.title == '周三课'), isEmpty);
  });

  test('splits a course when only one occurrence is overwritten', () {
    final course = Course(
      title: '跨周课程',
      teacher: '',
      weekday: 2,
      sessions: [1],
      weeks: [3, 4],
      campus: '',
      place: '',
      colorIndex: 0,
    );
    final adjusted = applyCourseAdjustments([course], {'20260916': '20260915'});
    expect(adjusted, hasLength(2));
    expect(adjusted.map((item) => item.weekday), containsAll(<int>[2, 3]));
    expect(
      adjusted.map((item) => item.weeks),
      containsAll(<List<int>>[
        [3, 4],
        [3],
      ]),
    );
  });
}

Course _course(String title, int weekday, int colorIndex) => Course(
  title: title,
  teacher: '',
  weekday: weekday,
  sessions: [1],
  weeks: [3],
  campus: '',
  place: '',
  colorIndex: colorIndex,
);
