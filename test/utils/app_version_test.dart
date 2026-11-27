import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/utils/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldLogoutAfterUpgrade', () {
    test('a legacy build without version tracking signs out once', () {
      expect(
        shouldLogoutAfterUpgrade(
          previous: null,
          current: '2.3.0',
          loggedIn: true,
        ),
        isTrue,
        reason: '2.2.0 had no last_run_version, so an account means an upgrade',
      );
    });

    test('only a real upgrade signs out', () {
      expect(
        shouldLogoutAfterUpgrade(
          previous: '2.2.0',
          current: '2.3.0',
          loggedIn: true,
        ),
        isTrue,
      );
      expect(
        shouldLogoutAfterUpgrade(
          previous: '2.3.0',
          current: '2.3.0',
          loggedIn: true,
        ),
        isFalse,
      );
      expect(
        shouldLogoutAfterUpgrade(
          previous: '2.3.0',
          current: '2.2.0',
          loggedIn: true,
        ),
        isFalse,
      );
      expect(
        shouldLogoutAfterUpgrade(
          previous: '2.2.0',
          current: '2.3.0',
          loggedIn: false,
        ),
        isFalse,
      );
    });
  });
}
