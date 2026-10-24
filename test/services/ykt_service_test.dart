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

  test('sums transactions newer than the balance snapshot', () {
    YktTransaction txn(String amount, String balance) => YktTransaction(
      time: '2026-10-24 19:00:00',
      location: '',
      amount: amount,
      balance: balance,
      type: '',
    );
    final txns = [
      txn('100', '36.57'),
      txn('-30', '36.57'),
      txn('-0.19', '36.57'),
      txn('-1.88', '34.69'),
      txn('-0.2', '36.76'),
      txn('-0.04', '38.83'),
      txn('-0.04', '38.87'),
      txn('-1.87', '36.96'),
      txn('-1.36', '38.91'),
    ];

    expect(yktUncommittedAmount('38.91', txns), '65.78 元');
  });

  test('returns zero when the newest transaction is the snapshot', () {
    final txns = [
      YktTransaction(
        time: '2026-10-24 19:09:24',
        location: '',
        amount: '100',
        balance: '38.91',
        type: '支付宝转账',
      ),
    ];

    expect(yktUncommittedAmount('38.91', txns), '0.00 元');
  });

  test('has no uncommitted amount without a matching snapshot', () {
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
