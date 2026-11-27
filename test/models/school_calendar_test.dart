import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/constants/time_slots.dart';
import 'package:xzitpocket/models/school_calendar.dart';

void main() {
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

  test(
    'removing calendar dates with applied rules still requires a refresh',
    () {
      final ordinary = SchoolDay(date: DateTime(2026, 10, 1));
      final adjusted = SchoolDay(
        date: DateTime(2026, 10, 2),
        adjustment: '20260925',
      );
      expect(
        schoolCalendarRulesChanged([ordinary, adjusted], [ordinary]),
        isTrue,
      );
      expect(schoolCalendarRulesChanged([ordinary], []), isFalse);
    },
  );

  test('uses the explicit lab flag even for periods 5/6', () {
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
