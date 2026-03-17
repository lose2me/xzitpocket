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
  });

  group('getCurrentSchoolTerm', () {
    test('uses autumn semester for September to December', () {
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 10, 1)), (2026, 1));
    });

    test('uses spring semester for January to August', () {
      expect(getCurrentSchoolTerm(reference: DateTime(2026, 3, 1)), (2025, 2));
    });
  });
}
