import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/pages/tools/campus_card_page.dart';
import 'package:xzitpocket/pages/tools/power_query_page.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/services/ykt_service.dart';

YktTransaction _txn({required String balance}) => YktTransaction(
  time: '2026-10-01 12:00:00',
  location: '食堂',
  amount: '-5.00',
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
    test('is balance minus the newest transaction remainder', () {
      final txns = [_txn(balance: '30.00'), _txn(balance: '40.00')];
      expect(yktUncommittedAmount('50.00', txns), '20.00 元');
    });

    test('supports negative results', () {
      expect(
        yktUncommittedAmount('10.00', [_txn(balance: '15.00')]),
        '-5.00 元',
      );
    });

    test('gives a placeholder without transactions', () {
      expect(yktUncommittedAmount('50.00', const []), '--');
    });

    test('gives a placeholder for unparsable values', () {
      expect(yktUncommittedAmount('', [_txn(balance: '15.00')]), '--');
      expect(yktUncommittedAmount('50.00', [_txn(balance: '')]), '--');
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
