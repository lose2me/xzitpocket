import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/pages/tools/campus_card_page.dart';
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

  test('uses the latest consumption row for the uncommitted amount', () {
    final txns = [
      YktTransaction(
        time: '2026-10-24 19:09:24',
        location: '转账前置机',
        amount: '100',
        balance: '36.57',
        type: '支付宝转账',
      ),
      YktTransaction(
        time: '2026-10-24 17:43:00',
        location: '东校区直饮水',
        amount: '-0.19',
        balance: '36.57',
        type: '持卡人消费',
      ),
    ];

    expect(yktUncommittedAmount('38.91', txns), '2.34 元');
  });

  test('has no uncommitted amount without a consumption row', () {
    final txns = [
      YktTransaction(
        time: '2026-10-24 19:09:24',
        location: '转账前置机',
        amount: '100',
        balance: '36.57',
        type: '支付宝转账',
      ),
    ];

    expect(yktUncommittedAmount('38.91', txns), '--');
  });
}
