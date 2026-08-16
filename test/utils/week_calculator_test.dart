import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/week_calculator.dart';

void main() {
  group('currentWeek', () {
    final semesterStart = DateTime(2026, 3, 2);

    test('returns 0 before semester start', () {
      expect(
        currentWeek(semesterStart, reference: DateTime(2026, 3, 1, 23, 59)),
        0,
      );
    });

    test('returns 1 on semester start day', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 3, 2)), 1);
    });

    test('returns next week after 7 days', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 3, 9)), 2);
    });

    test('returns 1 on last day of first week', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 3, 8)), 1);
    });

    test('returns correct week mid-semester', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 4, 20)), 8);
    });

    test('returns week beyond semester total', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 7, 1)), 18);
    });

    test('handles semester start that is not a Monday', () {
      final start = DateTime(2026, 9, 1); // Tuesday
      expect(currentWeek(start, reference: DateTime(2026, 8, 31)), 1);
      expect(currentWeek(start, reference: DateTime(2026, 9, 6)), 1);
      expect(currentWeek(start, reference: DateTime(2026, 9, 7)), 2);
      expect(currentWeek(start, reference: DateTime(2026, 8, 30)), 0);
    });

    test('returns 0 long before semester', () {
      expect(currentWeek(semesterStart, reference: DateTime(2025, 1, 1)), 0);
    });
  });

  group('weekDateRange', () {
    final semesterStart = DateTime(2026, 3, 2);

    test('returns correct range for week 1', () {
      final (monday, sunday) = weekDateRange(semesterStart, 1);
      expect(monday, DateTime(2026, 3, 2));
      expect(sunday, DateTime(2026, 3, 8));
    });

    test('returns correct range for week 2', () {
      final (monday, sunday) = weekDateRange(semesterStart, 2);
      expect(monday, DateTime(2026, 3, 9));
      expect(sunday, DateTime(2026, 3, 15));
    });

    test('anchors week 1 to Monday of the week containing start', () {
      final start = DateTime(2026, 9, 1); // Tuesday
      final (monday, sunday) = weekDateRange(start, 1);
      expect(monday, DateTime(2026, 8, 31));
      expect(sunday, DateTime(2026, 9, 6));
    });
  });

  group('weekDates', () {
    final semesterStart = DateTime(2026, 3, 2);

    test('returns 7 dates for any week', () {
      final dates = weekDates(semesterStart, 1);
      expect(dates.length, 7);
    });

    test('first date is Monday of the week', () {
      final dates = weekDates(semesterStart, 3);
      expect(dates[0], DateTime(2026, 3, 16));
      expect(dates[6], DateTime(2026, 3, 22));
    });
  });

  group('getCurrentSchoolTerm', () {
    test('September to December is term 1 of current year', () {
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 9, 1)), (2026, 1));
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 10, 1)), (2026, 1));
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 12, 31)), (2026, 1));
    });

    test('January is term 1 of previous year', () {
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 1, 1)), (2025, 1));
    });

    test('February to August is term 2 of previous year', () {
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 2, 1)), (2025, 2));
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 3, 1)), (2025, 2));
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 8, 31)), (2025, 2));
    });
  });
}
