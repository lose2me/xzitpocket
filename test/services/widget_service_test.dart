import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/course.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/services/widget_service.dart';

void main() {
  test('finds changed, cleared, and baseline-equal widget dates', () {
    final baseline = [
      _course(title: '周一课程', weekday: 1, weeks: const [1, 2]),
      _course(title: '周二课程', weekday: 2, weeks: const [1]),
    ];
    final current = [
      _course(title: '周一课程', weekday: 1, weeks: const [2]),
      _course(title: '周二课程', weekday: 2, weeks: const [1]),
      _course(title: '临时课程', weekday: 3, weeks: const [1]),
    ];

    expect(
      adjustedCourseDates(
        courses: current,
        originalCourses: baseline,
        semesterStart: DateTime(2026, 8, 31),
      ),
      {'2026-08-31', '2026-09-02'},
    );
  });

  test('serializes school calendar holiday and makeup dates', () {
    final days = [
      SchoolDay(date: DateTime(2026, 8, 31), adjustment: '/'),
      SchoolDay(date: DateTime(2026, 9, 1), adjustment: '20260902'),
      SchoolDay(date: DateTime(2026, 9, 2)),
    ];
    expect(schoolCalendarDates(days, (day) => day.isHoliday), {'2026-08-31'});
    expect(schoolCalendarDates(days, (day) => day.isMakeupClass), {
      '2026-09-01',
    });
  });
}

Course _course({
  required String title,
  required int weekday,
  required List<int> weeks,
}) => Course(
  title: title,
  teacher: '张老师',
  weekday: weekday,
  sessions: const [1, 2],
  weeks: weeks,
  campus: '中心校区',
  place: '教学楼101',
  colorIndex: 0,
  courseId: title,
);
