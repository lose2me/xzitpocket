import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/services/preferences_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesStorage.isCacheValid', () {
    test('does not expire merely because the clock passed 03:00', () {
      final fetchedAt = DateTime(2026, 8, 16, 2, 59, 30);
      final now = DateTime(2026, 8, 16, 3, 1);

      expect(
        PreferencesStorage.isCacheValid(
          fetchedAt.millisecondsSinceEpoch,
          const Duration(minutes: 10),
          now: now,
        ),
        isTrue,
      );
    });

    test('expires after the configured ttl', () {
      final fetchedAt = DateTime(2026, 8, 16, 2, 50);
      final now = DateTime(2026, 8, 16, 3, 1);

      expect(
        PreferencesStorage.isCacheValid(
          fetchedAt.millisecondsSinceEpoch,
          const Duration(minutes: 10),
          now: now,
        ),
        isFalse,
      );
    });

    test('rejects a cache timestamp in the future', () {
      final now = DateTime(2026, 8, 16, 3, 1);
      final fetchedAt = now.add(const Duration(minutes: 1));

      expect(
        PreferencesStorage.isCacheValid(
          fetchedAt.millisecondsSinceEpoch,
          const Duration(minutes: 10),
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('power cache metadata', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'saved_power_cache_date': 'legacy-value',
      });
      storage = PreferencesStorage();
      await storage.init();
    });

    test('stores the room id with cached data', () async {
      await storage.setPowerCache('{"balance":"10"}', roomId: 'A0101');

      expect(storage.getPowerCache(), '{"balance":"10"}');
      expect(storage.getPowerCacheRoomId(), 'A0101');
      expect(storage.getPowerCacheTime(), isNotNull);
    });

    test('clears current and legacy metadata', () async {
      await storage.setPowerCache('{"balance":"10"}', roomId: 'A0101');
      await storage.clearPowerCache();

      expect(storage.getPowerCache(), isNull);
      expect(storage.getPowerCacheRoomId(), isNull);
      expect(storage.getPowerCacheTime(), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('saved_power_cache_date'), isNull);
    });
  });
}
