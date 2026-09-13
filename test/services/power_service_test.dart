import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/power_service.dart';

void main() {
  test('daily usage date prefers the persisted ISO date', () {
    const usage = PowerDailyUsage(
      date: '9月12日 [昨天]',
      usage: '1.25',
      isoDate: '2025-09-12',
    );

    expect(usage.dateValue, DateTime(2025, 9, 12));
  });

  test('daily usage date keeps old localized caches sortable', () {
    const usage = PowerDailyUsage(date: '9月12日 [昨天]', usage: '1.25');

    expect(usage.dateValue.month, 9);
    expect(usage.dateValue.day, 12);
  });
}
