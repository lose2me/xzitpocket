import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/ui/date_range_calendar_sheet.dart';

void main() {
  test('student history starts on June 1 of the admission year', () {
    expect(
      studentHistoryStartDate('25070100246', today: DateTime(2026, 9, 13)),
      DateTime(2025, 6, 1),
    );
  });

  test('student history never starts in the future', () {
    expect(
      studentHistoryStartDate('26000000000', today: DateTime(2026, 3, 1)),
      DateTime(2026, 3, 1),
    );
  });
}
