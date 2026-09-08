import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/services/ykt_service.dart';

void main() {
  YktTransaction transaction(String time, String location) => YktTransaction(
    time: time,
    location: location,
    amount: '',
    balance: '',
    type: '',
  );

  test('sorts campus-card transactions from newest to oldest', () {
    final original = [
      transaction('2026-09-07 20:30:00', 'older'),
      transaction('2026/09/08 08:15:00', 'newest'),
      transaction('2026-09-08 07:45:00', 'middle'),
    ];

    final sorted = sortYktTransactionsNewestFirst(original);

    expect(sorted.map((item) => item.location), ['newest', 'middle', 'older']);
    expect(original.first.location, 'older');
  });

  test('keeps invalid transaction times after dated records', () {
    final sorted = sortYktTransactionsNewestFirst([
      transaction('', 'missing'),
      transaction('unknown', 'invalid'),
      transaction('2026-09-08 08:15:00', 'dated'),
    ]);

    expect(sorted.map((item) => item.location), [
      'dated',
      'missing',
      'invalid',
    ]);
  });
}
