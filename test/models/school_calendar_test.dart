import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/constants/semester_config.dart';
import 'package:xzitpocket/models/school_calendar.dart';

void main() {
  final calendar = semesterCalendar;

  test('uses the first school-calendar day as the semester start date', () {
    expect(calendar.semesterStartDate, DateTime(2026, 8, 31));
  });

  test('given the configured semester start when reading it '
      'then it points to the first school-calendar day', () {
    expect(semesterStartDate, calendar.semesterStartDate);
  });

  test('uses the Monday containing the first school day as week one', () {
    expect(calendar.start, DateTime(2026, 8, 31));
    expect(calendar.weekOf(DateTime(2026, 8, 30, 23, 59)), 0);
    expect(calendar.weekOf(DateTime(2026, 8, 31)), 1);
    expect(calendar.weekOf(DateTime(2026, 9, 6, 23, 59)), 1);
    expect(calendar.weekOf(DateTime(2026, 9, 7)), 2);
  });

  test('returns seven dates for a timetable week', () {
    expect(calendar.weekDates(1), [
      DateTime(2026, 8, 31),
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 2),
      DateTime(2026, 9, 3),
      DateTime(2026, 9, 4),
      DateTime(2026, 9, 5),
      DateTime(2026, 9, 6),
    ]);
    expect(
      calendar.daysOfWeek(4).map((day) => day.date),
      contains(DateTime(2026, 9, 25)),
    );
  });

  test('exposes holiday names in their corresponding weeks', () {
    expect(calendar.festivalNamesInWeek(4), contains('中秋'));
    expect(calendar.festivalNamesInWeek(5), contains('国庆'));
    expect(calendar.festivalNamesInWeek(18), contains('元旦'));
    expect(calendar.totalWeeks, 19);
  });

  group('custom calendar boundaries', () {
    test(
      'given a first school day on Tuesday when building the calendar '
      'then the exact start date and Monday week anchor are both preserved',
      () {
        final custom = SemesterCalendar([
          SchoolDay(date: DateTime(2026, 9, 1), weekday: 2, holiday: false),
          SchoolDay(date: DateTime(2026, 9, 2), weekday: 3, holiday: false),
          SchoolDay(date: DateTime(2026, 9, 3), weekday: 4, holiday: false),
        ]);

        expect(custom.semesterStartDate, DateTime(2026, 9, 1));
        expect(custom.start, DateTime(2026, 8, 31));
        expect(custom.weekOf(DateTime(2026, 8, 31)), 1);
        expect(custom.daysOfWeek(1), hasLength(3));
        expect(custom.festivalNamesInWeek(1), isEmpty);
      },
    );

    test('given an empty school-calendar list when reading derived values '
        'then fallback dates and empty collections are returned', () {
      final empty = SemesterCalendar(const []);

      expect(empty.semesterStartDate, DateTime(2026, 8, 31));
      expect(empty.totalWeeks, 0);
      expect(empty.daysOfWeek(1), isEmpty);
      expect(empty.festivalNamesInWeek(1), isEmpty);
    });
  });

  test('encodes and decodes a control-service calendar payload', () {
    final days = [
      SchoolDay(date: DateTime(2027, 2, 23), weekday: 2, holiday: false),
      SchoolDay(
        date: DateTime(2027, 2, 22),
        weekday: 1,
        holiday: true,
        festival: '校庆',
      ),
    ];
    final decoded = schoolCalendarDaysFromJson(schoolCalendarDaysToJson(days));
    expect(decoded, [days[1], days[0]]);
  });

  test('roundtrips cloud course adjustment parameters', () {
    final days = [
      SchoolDay(
        date: DateTime(2027, 2, 22),
        weekday: 1,
        holiday: false,
        adjustment: '20270223',
      ),
      SchoolDay(
        date: DateTime(2027, 2, 23),
        weekday: 2,
        holiday: false,
        adjustment: '/',
      ),
    ];
    final decoded = schoolCalendarDaysFromJson(schoolCalendarDaysToJson(days));
    expect(decoded, days);
  });

  test('rejects invalid cloud course adjustment parameters', () {
    expect(
      () => schoolCalendarDaysFromJson(
        '[{"date":"2027-02-22","weekday":1,"holiday":false,"adjustment":"20270231"}]',
      ),
      throwsFormatException,
    );
  });

  test('rejects non-contiguous calendar data', () {
    expect(
      () => schoolCalendarDaysFromJson(
        '[{"date":"2027-02-22","weekday":1,"holiday":false},{"date":"2027-02-24","weekday":3,"holiday":false}]',
      ),
      throwsFormatException,
    );
  });
}
