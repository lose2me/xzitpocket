import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/services/preferences_storage.dart';
import 'package:xzitpocket/utils/app_version.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isVersionUpgrade', () {
    test('a fresh install is not an upgrade', () {
      expect(isVersionUpgrade(null, '2.3.0'), isFalse);
      expect(isVersionUpgrade('', '2.3.0'), isFalse);
    });

    test('a newer numeric version is an upgrade', () {
      expect(isVersionUpgrade('2.2.0', '2.3.0'), isTrue);
      expect(isVersionUpgrade('2.2.0', '2.2.1'), isTrue);
      expect(isVersionUpgrade('2.2.9', '2.10.0'), isTrue);
      expect(isVersionUpgrade('2.2', '2.2.1'), isTrue);
    });

    test('the same or an older version is not an upgrade', () {
      expect(isVersionUpgrade('2.3.0', '2.3.0'), isFalse);
      expect(isVersionUpgrade('2.3.0', '2.2.9'), isFalse);
      expect(isVersionUpgrade('2.10.0', '2.9.0'), isFalse);
      expect(isVersionUpgrade('2.3.0', '2.3'), isFalse);
    });

    test('suffixes compare by their numeric prefix', () {
      expect(isVersionUpgrade('2.2.0-beta', '2.3.0'), isTrue);
      expect(isVersionUpgrade('2.2.0+4220', '2.2.0+4239'), isFalse);
      expect(isVersionUpgrade('release', '2.3.0'), isFalse);
    });
  });

  group('shouldLogoutAfterUpgrade', () {
    test('a fresh install without an account never signs out', () {
      expect(
        shouldLogoutAfterUpgrade(
          previous: null,
          current: '2.3.0',
          loggedIn: false,
        ),
        isFalse,
      );
    });

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

  group('PreferencesStorage last run version', () {
    test('stores and reads the version used for upgrade detection', () async {
      SharedPreferences.setMockInitialValues({'student_id': '20260001'});
      final storage = PreferencesStorage();
      await storage.init();
      expect(storage.getLastRunVersion(), isNull);
      await storage.setLastRunVersion('2.3.0');
      expect(storage.getLastRunVersion(), '2.3.0');
      // It is device state: logging out keeps it so the next launch does not
      // sign the account out twice.
      await storage.clearStudentInfo();
      expect(storage.getLastRunVersion(), '2.3.0');
    });
  });
}
