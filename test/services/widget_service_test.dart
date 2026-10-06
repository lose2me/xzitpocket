import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/school_calendar.dart';
import 'package:xzitpocket/services/widget_service.dart';

void main() {
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
