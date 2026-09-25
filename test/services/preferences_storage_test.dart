import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xzitpocket/models/app_settings.dart';
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

  group('learning cache metadata', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('stores and clears the question bank cache timestamp', () async {
      await storage.setLearningQuestionBankCache('[{"id":"bank-1"}]');

      expect(storage.getLearningQuestionBankCache(), '[{"id":"bank-1"}]');
      expect(storage.getLearningQuestionBankCacheTime(), isNotNull);

      await storage.clearLearningQuestionBankCache();

      expect(storage.getLearningQuestionBankCache(), isNull);
      expect(storage.getLearningQuestionBankCacheTime(), isNull);
    });
  });

  group('appearance settings', () {
    late PreferencesStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('roundtrips timetable appearance settings', () async {
      await storage.setThemeColor('blue');
      await storage.setTimetableBackgroundPath('/tmp/background.jpg');
      await storage.setTimetableBackgroundOriginalPath('/tmp/original.png');
      await storage.setTimetableBackgroundFullscreen(false);
      await storage.setTimetableBackgroundOpacity(0.65);
      await storage.setTimetableComponentOpacity(0.72);
      await storage.setTimetableGridOpacity(0.42);
      await storage.setTimetableCourseTextSize(14);
      await storage.setTimetableTimeTextSize(10);
      await storage.setTimetableDateTextSize(13);
      await storage.setTimetableCourseBorderWidth(1.2);
      await storage.setTimetableCourseBorderOpacity(0.35);
      await storage.setShowTimetableGridLines(false);
      await storage.setShowTodayGridLines(false);

      expect(storage.getThemeColor(), 'blue');
      expect(storage.getTimetableBackgroundPath(), '/tmp/background.jpg');
      expect(storage.getTimetableBackgroundOriginalPath(), '/tmp/original.png');
      expect(storage.getTimetableBackgroundFullscreen(), isFalse);
      expect(storage.getTimetableBackgroundOpacity(), 0.65);
      expect(storage.getTimetableComponentOpacity(), 0.72);
      expect(storage.getTimetableGridOpacity(), 0.42);
      expect(storage.getTimetableCourseTextSize(), 14);
      expect(storage.getTimetableTimeTextSize(), 10);
      expect(storage.getTimetableDateTextSize(), 13);
      expect(storage.getTimetableCourseBorderWidth(), 1.2);
      expect(storage.getTimetableCourseBorderOpacity(), 0.35);
      expect(storage.getShowTimetableGridLines(), isFalse);
      expect(storage.getShowTodayGridLines(), isFalse);
    });

    test('roundtrips hidden service features', () async {
      await storage.setHiddenServiceFeatures([
        AppServiceFeature.power.storageValue,
        AppServiceFeature.learning.storageValue,
      ]);

      expect(storage.getHiddenServiceFeatures(), {
        AppServiceFeature.power.storageValue,
        AppServiceFeature.learning.storageValue,
      });
    });

    test('clamps timetable background opacity', () async {
      await storage.setTimetableBackgroundOpacity(2);
      expect(storage.getTimetableBackgroundOpacity(), 1);

      await storage.setTimetableBackgroundOpacity(-1);
      expect(storage.getTimetableBackgroundOpacity(), 0);
    });

    test('clamps timetable component opacity', () async {
      await storage.setTimetableComponentOpacity(2);
      expect(storage.getTimetableComponentOpacity(), 1);

      await storage.setTimetableComponentOpacity(-1);
      expect(storage.getTimetableComponentOpacity(), 0);
    });

    test(
      'uses the legacy component opacity when border opacity is unset',
      () async {
        await storage.setTimetableComponentOpacity(0.28);

        expect(storage.getTimetableCourseBorderOpacity(), 0.28);
      },
    );

    test('clamps timetable grid opacity', () async {
      await storage.setTimetableGridOpacity(2);
      expect(storage.getTimetableGridOpacity(), 1);

      await storage.setTimetableGridOpacity(-1);
      expect(storage.getTimetableGridOpacity(), 0);
    });

    test('clamps timetable typography and border settings', () async {
      await storage.setTimetableCourseTextSize(30);
      await storage.setTimetableTimeTextSize(1);
      await storage.setTimetableDateTextSize(30);
      await storage.setTimetableCourseBorderWidth(5);
      await storage.setTimetableCourseBorderOpacity(2);

      expect(storage.getTimetableCourseTextSize(), 18);
      expect(storage.getTimetableTimeTextSize(), 8);
      expect(storage.getTimetableDateTextSize(), 18);
      expect(storage.getTimetableCourseBorderWidth(), 3);
      expect(storage.getTimetableCourseBorderOpacity(), 1);

      await storage.setTimetableCourseBorderOpacity(-1);
      expect(storage.getTimetableCourseBorderOpacity(), 0);
    });

    test('rounds timetable dimensions to a tenth of a pixel', () async {
      await storage.setTimetableCourseTextSize(14.06);
      await storage.setTimetableTimeTextSize(10.04);
      await storage.setTimetableDateTextSize(13.25);
      await storage.setTimetableCourseBorderWidth(1.26);

      expect(storage.getTimetableCourseTextSize(), 14.1);
      expect(storage.getTimetableTimeTextSize(), 10.0);
      expect(storage.getTimetableDateTextSize(), 13.3);
      expect(storage.getTimetableCourseBorderWidth(), 1.3);
    });

    test('resets timetable appearance settings to defaults', () async {
      await storage.setTimetableBackgroundPath('/tmp/background.jpg');
      await storage.setTimetableBackgroundOriginalPath('/tmp/original.png');
      await storage.setTimetableBackgroundOpacity(0.8);
      await storage.setTimetableComponentOpacity(0.2);
      await storage.setTimetableGridOpacity(0.9);
      await storage.setTimetableCourseTextSize(16);
      await storage.setTimetableTimeTextSize(15);
      await storage.setTimetableDateTextSize(14);
      await storage.setTimetableCourseBorderWidth(2);
      await storage.setTimetableCourseBorderOpacity(0.2);
      await storage.setShowTimetableGridLines(false);
      await storage.setShowTodayGridLines(true);

      await storage.resetTimetableAppearance();

      expect(storage.getTimetableBackgroundPath(), isNull);
      expect(storage.getTimetableBackgroundOriginalPath(), isNull);
      expect(storage.getTimetableBackgroundFullscreen(), isTrue);
      expect(storage.getTimetableBackgroundOpacity(), 0.5);
      expect(storage.getTimetableComponentOpacity(), 0.7);
      expect(storage.getTimetableGridOpacity(), 0.5);
      expect(storage.getTimetableCourseTextSize(), 12);
      expect(storage.getTimetableTimeTextSize(), 11);
      expect(storage.getTimetableDateTextSize(), 12);
      expect(storage.getTimetableCourseBorderWidth(), 0.5);
      expect(storage.getTimetableCourseBorderOpacity(), 0.7);
      expect(storage.getShowTimetableGridLines(), isTrue);
      expect(storage.getShowTodayGridLines(), isFalse);
    });
  });
}
