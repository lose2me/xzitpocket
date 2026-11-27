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

    test('returns 1 on last day of first week', () {
      expect(currentWeek(semesterStart, reference: DateTime(2026, 3, 8)), 1);
    });

    test('given a reference late on the semester-start date when calculating the week '
        'then the time component does not change the result', () {
      expect(
        currentWeek(semesterStart, reference: DateTime(2026, 3, 2, 23, 59, 59)),
        1,
      );
    });
  });

  group('weekDateRange', () {
    test('anchors week 1 to Monday of the week containing start', () {
      final start = DateTime(2026, 9, 1); // Tuesday
      final (monday, sunday) = weekDateRange(start, 1);
      expect(monday, DateTime(2026, 8, 31));
      expect(sunday, DateTime(2026, 9, 6));
    });
  });

  group('getCurrentSchoolTerm', () {
    test('given the month boundary when determining a school term '
        'then July is spring and August is autumn', () {
      expect(getCurrentSchoolTerm(semesterStart: DateTime(2026, 1, 1)), (
        2025,
        2,
      ));
      expect(getCurrentSchoolTerm(semesterStart: DateTime(2026, 7, 31)), (
        2025,
        2,
      ));
      expect(getCurrentSchoolTerm(semesterStart: DateTime(2026, 8, 1)), (
        2026,
        1,
      ));
    });
  });
}
