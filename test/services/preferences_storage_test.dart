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
  });

  group('share codes', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('clears both codes when the account caches are cleared', () async {
      await storage.setShareCode('1', 'ABCDE1');
      await storage.setShareCode('2', 'FGHJK2');

      await storage.clearUserAccountCaches();

      expect(storage.getShareCode('1'), isNull);
      expect(storage.getShareCode('2'), isNull);
    });

    test('keeps one code per kind until it is cleared', () async {
      expect(storage.getShareCode('1'), isNull);
      await storage.setShareCode('1', 'ABCDE1');
      await storage.setShareCode('2', 'FGHJK2');

      expect(storage.getShareCode('1'), 'ABCDE1');
      expect(storage.getShareCode('2'), 'FGHJK2');

      await storage.setShareCode('1', 'LMNPQ1');
      expect(storage.getShareCode('1'), 'LMNPQ1');
      expect(storage.getShareCode('2'), 'FGHJK2');

      await storage.setShareCode('1', null);
      expect(storage.getShareCode('1'), isNull);
      expect(storage.getShareCode('2'), 'FGHJK2');
    });
  });

  group('student profile', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('stores and clears college and class with the student', () async {
      await storage.setStudentId('2023000001');
      await storage.setStudentName('测试用户');
      await storage.setCollegeName('计算机学院');
      await storage.setClassName('计科2301班');

      expect(storage.getCollegeName(), '计算机学院');
      expect(storage.getClassName(), '计科2301班');

      await storage.clearStudentInfo();

      expect(storage.getStudentId(), isNull);
      expect(storage.getStudentName(), isNull);
      expect(storage.getCollegeName(), isNull);
      expect(storage.getClassName(), isNull);
    });
  });

  group('resource centre and update prompt caches', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('clears the course list, course details and prompt version', () async {
      await storage.setResourceCenterCache('{"version":"v1","courses":[]}');
      await storage.setResourceCourseCache('C1', '{"version":"v1"}');
      await storage.setUpdatePromptedVersion('2.2.0');

      expect(storage.getResourceCenterCache(), isNotNull);
      expect(storage.getResourceCourseCache('C1'), isNotNull);
      expect(storage.getUpdatePromptedVersion(), '2.2.0');

      await storage.clearUserToolCaches();

      expect(storage.getResourceCenterCache(), isNull);
      expect(storage.getResourceCourseCache('C1'), isNull);
      expect(storage.getUpdatePromptedVersion(), isNull);
    });
  });

  group('appearance settings', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test(
      'resets timetable customization and preserves unrelated settings',
      () async {
        await storage.setThemePreference('dark');
        await storage.setThemeColor('blue');
        await storage.setLastCustomThemeColor(0xFF203040);
        await storage.setTimetableBackgroundPath('/tmp/background.jpg');
        await storage.setTimetableCourseTextTemplate('{课程}');
        await storage.setTimetableSectionHeight(72);
        await storage.setCourseReminderEnabled(true);

        await storage.resetTimetableAppearance();

        expect(storage.getThemePreference(), 'dark');
        expect(storage.getThemeColor(), isNull);
        expect(storage.getLastCustomThemeColor(), 0xFF203040);
        expect(storage.getTimetableBackgroundPath(), isNull);
        expect(storage.getTimetableCourseTextTemplate(), isNull);
        expect(storage.hasTimetableSectionHeight(), isFalse);
        expect(storage.getCourseReminderEnabled(), isTrue);
      },
    );
  });
}
