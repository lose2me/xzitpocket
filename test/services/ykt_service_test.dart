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

  test('sums transfers that are still waiting for a card write', () {
    // 账号 25130100255：余额 9.48，待圈存 10.00。
    YktTransaction txn(String amount, String balance, String terminal) =>
        YktTransaction(
          time: '2026-10-26 22:05:13',
          location: '',
          amount: amount,
          balance: balance,
          type: '',
          terminal: terminal,
        );
    final txns = [
      txn('10', '9.48', '转帐前置机'),
      txn('-0.06', '9.48', '二期公寓水控'),
      txn('-0.85', '9.54', '二期公寓水控'),
    ];

    expect(yktUncommittedAmount('9.48', txns), '10.00 元');
  });

  test('counts a lone transfer that is the only transaction', () {
    // 账号 25070100246：余额 16.43，待圈存 10.00。
    final txns = [
      YktTransaction(
        time: '2026-05-23 17:10:26',
        location: '',
        amount: '10',
        balance: '16.43',
        type: '支付宝转账',
        terminal: '转帐前置机',
      ),
    ];

    expect(yktUncommittedAmount('16.43', txns), '10.00 元');
  });

  test('keeps an unpaid deduction negative', () {
    // 账号 23010300238：余额 24.21，待圈存 -20.00（电费代扣还没刷卡）。
    final txns = [
      YktTransaction(
        time: '2026-10-24 09:12:00',
        location: '电费',
        amount: '-20',
        balance: '24.21',
        type: '持卡人消费',
        terminal: '转帐前置机',
      ),
      YktTransaction(
        time: '2026-10-20 11:40:00',
        location: '第二餐厅二层总',
        amount: '-7',
        balance: '44.21',
        type: '持卡人消费',
        terminal: '二期食堂',
      ),
    ];

    expect(yktUncommittedAmount('24.21', txns), '-20.00 元');
  });

  test('reports zero when the newest transaction already wrote the card', () {
    // 账号 26130100211：余额 35.34，待圈存 0.00。
    expect(
      yktUncommittedAmount('35.34', [
        YktTransaction(
          time: '2026-10-17 12:14:04',
          location: '中心直饮水水控',
          amount: '-0.31',
          balance: '35.34',
          type: '持卡人消费',
          terminal: '直饮水控水',
        ),
      ]),
      '0.00 元',
    );
  });

  test('reports zero once a written transfer moved the balance', () {
    final txns = [
      YktTransaction(
        time: '2026-10-24 19:09:24',
        location: '',
        amount: '20',
        balance: '0.73',
        type: '支付宝转账',
        terminal: '转帐前置机',
      ),
    ];

    expect(yktUncommittedAmount('20.73', txns), '0.00 元');
  });

  test('has no uncommitted amount without transactions', () {
    expect(yktUncommittedAmount('38.91', const []), '--');
  });

  test('takes the card balance from the newest transaction', () {
    // 账号 23010300238：一卡通中心返回 1.84，卡内实际是 24.21。
    final txns = [
      YktTransaction(
        time: '2026-10-26 02:00:19',
        location: '电费',
        amount: '-20',
        balance: '24.21',
        type: '代扣代缴',
        terminal: '转帐前置机',
      ),
      YktTransaction(
        time: '2026-10-24 16:57:00',
        location: '东校区公寓水控',
        amount: '-1.69',
        balance: '24.21',
        type: '持卡人消费',
        terminal: '东校区5.0水控',
      ),
    ];

    expect(yktCardBalance('1.84', txns), '24.21');
    expect(yktUncommittedAmount(yktCardBalance('1.84', txns), txns), '-20.00 元');
  });

  test('falls back to the centre balance without transactions', () {
    expect(yktCardBalance('35.34', const []), '35.34');
  });
}
