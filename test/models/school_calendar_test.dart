import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/constants/semester_config.dart';
import 'package:xzitpocket/constants/time_slots.dart';
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

  test('exposes calendar names in their corresponding weeks', () {
    expect(calendar.namesInWeek(4), contains('中秋'));
    expect(calendar.namesInWeek(5), contains('国庆'));
    expect(calendar.namesInWeek(18), contains('元旦'));
    expect(calendar.totalWeeks, 19);
  });

  group('custom calendar boundaries', () {
    test(
      'given a first school day on Tuesday when building the calendar '
      'then the exact start date and Monday week anchor are both preserved',
      () {
        final custom = SemesterCalendar([
          SchoolDay(date: DateTime(2026, 9, 1)),
          SchoolDay(date: DateTime(2026, 9, 2)),
          SchoolDay(date: DateTime(2026, 9, 3)),
        ]);

        expect(custom.semesterStartDate, DateTime(2026, 9, 1));
        expect(custom.start, DateTime(2026, 8, 31));
        expect(custom.weekOf(DateTime(2026, 8, 31)), 1);
        expect(custom.daysOfWeek(1), hasLength(3));
        expect(custom.namesInWeek(1), isEmpty);
      },
    );

    test('given an empty school-calendar list when reading derived values '
        'then fallback dates and empty collections are returned', () {
      final empty = SemesterCalendar(const []);

      expect(empty.semesterStartDate, DateTime(2026, 8, 31));
      expect(empty.totalWeeks, 0);
      expect(empty.daysOfWeek(1), isEmpty);
      expect(empty.namesInWeek(1), isEmpty);
    });
  });

  test('encodes and decodes a control-service calendar payload', () {
    final days = [
      SchoolDay(date: DateTime(2027, 2, 23)),
      SchoolDay(date: DateTime(2027, 2, 22), name: '校庆'),
    ];
    final decoded = schoolCalendarDaysFromJson(schoolCalendarDaysToJson(days));
    expect(decoded, [days[1], days[0]]);
  });

  test('roundtrips cloud course adjustment parameters', () {
    final days = [
      SchoolDay(date: DateTime(2027, 2, 22), adjustment: '20270223'),
      SchoolDay(date: DateTime(2027, 2, 23), adjustment: '/'),
    ];
    final decoded = schoolCalendarDaysFromJson(schoolCalendarDaysToJson(days));
    expect(decoded, days);
  });

  test('rejects invalid cloud course adjustment parameters', () {
    expect(
      () => schoolCalendarDaysFromJson(
        '{"days":[{"date":"2027-02-22","name":"","adjustment":"20270231"}]}',
      ),
      throwsFormatException,
    );
  });

  test('rejects non-contiguous calendar data', () {
    expect(
      () => schoolCalendarDaysFromJson(
        '{"days":[{"date":"2027-02-22","name":"","adjustment":""},{"date":"2027-02-24","name":"","adjustment":""}]}',
      ),
      throwsFormatException,
    );
  });

  test('derives weekdays from ISO dates and rejects the legacy payload', () {
    final decoded = schoolCalendarDaysFromJson(
      '{"days":[{"date":"2027-02-22","name":"校庆","adjustment":""}]}',
    );
    expect(decoded.single.weekday, DateTime.monday);
    expect(decoded.single.name, '校庆');
    expect(
      () => schoolCalendarDaysFromJson(
        '[{"date":"2027-02-22","weekday":1,"holiday":false}]',
      ),
      throwsFormatException,
    );
  });

  test('recognizes only eight-digit adjustments as makeup class days', () {
    expect(
      SchoolDay(
        date: DateTime(2027, 2, 22),
        adjustment: '20260713',
      ).isMakeupClass,
      isTrue,
    );
    expect(
      SchoolDay(date: DateTime(2027, 2, 22), adjustment: '/').isMakeupClass,
      isFalse,
    );
    expect(
      SchoolDay(date: DateTime(2027, 2, 22), adjustment: '').isMakeupClass,
      isFalse,
    );
    expect(
      SchoolDay(
        date: DateTime(2027, 2, 22),
        adjustment: '2026-07-13',
      ).isMakeupClass,
      isFalse,
    );
  });

  test('recognizes slash adjustments as holidays', () {
    expect(
      SchoolDay(date: DateTime(2027, 2, 22), adjustment: '/').isHoliday,
      isTrue,
    );
    expect(
      SchoolDay(date: DateTime(2027, 2, 22), adjustment: '').isHoliday,
      isFalse,
    );
  });

  test('detects holiday and make-up-day changes between snapshots', () {
    final previous = [
      SchoolDay(date: DateTime(2026, 9, 25), name: '中秋'),
      SchoolDay(date: DateTime(2026, 10, 1), name: '国庆'),
      SchoolDay(date: DateTime(2026, 10, 11)),
    ];
    final next = [
      SchoolDay(date: DateTime(2026, 9, 25), name: '中秋', adjustment: '/'),
      SchoolDay(date: DateTime(2026, 10, 1), name: '国庆', adjustment: '/'),
      SchoolDay(date: DateTime(2026, 10, 11), adjustment: '20260925'),
    ];

    expect(schoolCalendarRulesChanged(previous, next), isTrue);
    expect(schoolCalendarRulesChanged(next, next), isFalse);
  });

  test('decodes control timetable periods alongside the calendar', () {
    final payload = schoolCalendarPayloadFromJson(
      '{"days":[{"date":"2027-02-22","name":"","adjustment":""}],'
      '"slots":[{"index":1,"start":"07:30","end":"08:15","lab":true},'
      '{"index":2,"start":"08:25","end":"09:10","lab":false}]}',
    );
    expect(payload.slots, const [
      TimeSlot(index: 1, start: '07:30', end: '08:15', lab: true),
      TimeSlot(index: 2, start: '08:25', end: '09:10'),
    ]);
  });

  test('marks periods 5/6 as lab when the flag is missing', () {
    expect(
      timeSlotFromJson({'index': 5, 'start': '12:00', 'end': '12:45'})!.lab,
      isTrue,
    );
    expect(
      timeSlotFromJson({'index': 6, 'start': '12:55', 'end': '13:40'})!.lab,
      isTrue,
    );
    expect(
      timeSlotFromJson({'index': 1, 'start': '08:00', 'end': '08:45'})!.lab,
      isFalse,
    );
    expect(
      timeSlotFromJson({
        'index': 5,
        'start': '12:00',
        'end': '12:45',
        'lab': false,
      })!.lab,
      isFalse,
    );
  });

  test(
    'falls back to built-in periods when slots are missing or malformed',
    () {
      final missing = schoolCalendarPayloadFromJson(
        '{"days":[{"date":"2027-02-22","name":"","adjustment":""}]}',
      );
      expect(missing.slots, kDefaultTimeSlots);

      final malformed = schoolCalendarPayloadFromJson(
        '{"days":[{"date":"2027-02-22","name":"","adjustment":""}],'
        '"slots":[{"index":2,"start":"07:30","end":"08:15"}]}',
      );
      expect(malformed.slots, kDefaultTimeSlots);
    },
  );

  test('roundtrips the calendar payload including periods', () {
    final json = schoolCalendarPayloadToJson(
      days: [SchoolDay(date: DateTime(2027, 2, 22))],
      slots: const [
        TimeSlot(index: 1, start: '08:00', end: '08:45', lab: true),
      ],
    );
    final payload = schoolCalendarPayloadFromJson(json);
    expect(payload.days, [SchoolDay(date: DateTime(2027, 2, 22))]);
    expect(payload.slots, const [
      TimeSlot(index: 1, start: '08:00', end: '08:45', lab: true),
    ]);
  });
}
