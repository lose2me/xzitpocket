import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/tools/campus_card_page.dart';
import 'package:xzitpocket/pages/tools/power_query_page.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/services/ykt_service.dart';

YktTransaction _txn({required String balance, String amount = '-5.00'}) =>
    YktTransaction(
      time: '2026-10-01 12:00:00',
      location: '食堂',
      amount: amount,
      balance: balance,
      type: '消费',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('powerAmountAsMoney', () {
    test('converts kWh to money with two decimals', () {
      expect(powerAmountAsMoney('100', '0.55'), '55.00');
      expect(powerAmountAsMoney('12.5', '0.546'), '6.83');
    });

    test('falls back to a placeholder for unparsable values', () {
      expect(powerAmountAsMoney('', '0.55'), '-');
      expect(powerAmountAsMoney('100', ''), '-');
    });
  });

  group('yktUncommittedAmount', () {
    test('sums transactions newer than the balance snapshot', () {
      final txns = [
        _txn(balance: '30.00', amount: '-5.00'),
        _txn(balance: '50.00', amount: '-10.00'),
      ];
      expect(yktUncommittedAmount('50.00', txns), '-5.00 元');
    });

    test('gives a placeholder when no transaction matches the balance', () {
      expect(yktUncommittedAmount('50.00', [_txn(balance: '15.00')]), '--');
    });

    test('gives a placeholder without transactions', () {
      expect(yktUncommittedAmount('50.00', const []), '--');
    });

    test('gives a placeholder for unparsable values', () {
      expect(yktUncommittedAmount('', [_txn(balance: '15.00')]), '--');
    });
  });

  group('power unit persistence', () {
    test('defaults to kWh and round-trips the money unit', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PreferencesStorage();
      await storage.init();

      expect(storage.getPowerUnitShowMoney(), isFalse);
      await storage.setPowerUnitShowMoney(true);
      expect(storage.getPowerUnitShowMoney(), isTrue);
    });
  });
}
