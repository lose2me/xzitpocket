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
      SharedPreferences.setMockInitialValues({});
      storage = PreferencesStorage();
      await storage.init();
    });

    test('stores the room id with cached data', () async {
      await storage.setPowerCache('{"balance":"10"}', roomId: 'A0101');

      expect(storage.getPowerCache(), '{"balance":"10"}');
      expect(storage.getPowerCacheRoomId(), 'A0101');
      expect(storage.getPowerCacheTime(), isNotNull);
    });

    test('clears cached data and metadata', () async {
      await storage.setPowerCache('{"balance":"10"}', roomId: 'A0101');
      await storage.clearPowerCache();

      expect(storage.getPowerCache(), isNull);
      expect(storage.getPowerCacheRoomId(), isNull);
      expect(storage.getPowerCacheTime(), isNull);
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

    test('uses the timetable teacher display defaults', () {
      expect(storage.getTimetableHideTeacher(), isTrue);
      expect(storage.getTimetableHideTeacherBrackets(), isTrue);
      expect(storage.getTimetableCourseCornerRadius(), 6.0);
      expect(storage.getTimetableCourseInnerPadding(), 2.0);
      expect(storage.getTimetableSectionHeight(), 60.0);
      expect(storage.getTimetableDayHeaderHeight(), 40.0);
      expect(storage.getTimetableCourseOuterPadding(), 1.5);
      expect(storage.getTimetableCourseFontScale(), 0.95);
      expect(storage.getTimetableAddBlankLineAfterTitle(), isFalse);
      expect(storage.getTimetableDashedBorderDensity(), 1.0);
      expect(storage.getTimetableGridOpacity(), 0.5);
      expect(storage.getTimetableCourseBorderOpacity(), 0.7);
    });

    test('roundtrips timetable appearance settings', () async {
      await storage.setThemeColor('blue');
      await storage.setCustomThemeColor(0xFF123456);
      await storage.setLastCustomThemeColor(0xFF654321);
      await storage.setCourseReminderEnabled(true);
      await storage.setCourseReminderMinutes(30);
      await storage.setWearableNotificationCompatibility(true);
      await storage.setWidgetThemePreference('dark');
      await storage.setWidgetFontScale(1.4);
      await storage.setWidgetBackgroundAlpha(0.65);
      await storage.setWidgetBackgroundColor(0xFFABCDEF);
      await storage.setLastCustomWidgetBackgroundColor(0xFFABCDEF);
      await storage.setWidgetBackgroundPath('/tmp/widget-light.jpg');
      await storage.setWidgetDarkBackgroundPath('/tmp/widget-dark.jpg');
      await storage.setWidgetUseLightBackgroundInDarkMode(true);
      await storage.setWidgetTextColor(0xFF123456);
      await storage.setLastCustomWidgetTextColor(0xFF123456);
      await storage.setWidgetTextOpacity(0.75);
      await storage.setWidgetHideTeacher(true);
      await storage.setWidgetHideLocation(true);
      await storage.setWidgetHideDate(true);
      await storage.setTimetableHideTeacher(false);
      await storage.setTimetableHideTeacherBrackets(false);
      await storage.setTimetableAddBlankLineAfterTitle(true);
      await storage.setTimetableDashedBorderDensity(1.5);
      await storage.setTimetablePageTextColor(0xFF111111);
      await storage.setTimetableLastCustomPageTextColor(0xFF121212);
      await storage.setTimetableCourseTextColor(0xFF222222);
      await storage.setTimetableLastCustomCourseTextColor(0xFF232323);
      await storage.setTimetableCourseBorderColor(0xFF333333);
      await storage.setTimetableLastCustomCourseBorderColor(0xFF343434);
      await storage.setTimetableBackgroundPath('/tmp/background.jpg');
      await storage.setTimetableDarkBackgroundPath('/tmp/background-dark.jpg');
      await storage.setTimetableUseLightBackgroundInDarkMode(true);
      await storage.setPageBackgroundColor('teal');
      await storage.setToastOpacity(0.8);
      await storage.setTimetableGridOpacity(0.42);
      await storage.setTimetableGridLineColor(0xFF454545);
      await storage.setTimetableLastCustomGridLineColor(0xFF464646);
      await storage.setTimetableGridLineWidth(1.5);
      await storage.setTimetableCourseTextSize(14);
      await storage.setTimetableTimeTextSize(10);
      await storage.setTimetableDateTextSize(13);
      await storage.setTimetableCourseBorderWidth(1.2);
      await storage.setTimetableCourseBorderOpacity(0.35);
      await storage.setShowTimetableGridLines(false);
      await storage.setShowTodayGridLines(false);
      await storage.setTimetableTodayLineColor(0xFF565656);
      await storage.setTimetableLastCustomTodayLineColor(0xFF575757);
      await storage.setTimetableTodayLineWidth(2.5);

      expect(storage.getThemeColor(), 'blue');
      expect(storage.getCustomThemeColor(), 0xFF123456);
      expect(storage.getLastCustomThemeColor(), 0xFF654321);
      expect(storage.getCourseReminderEnabled(), isTrue);
      expect(storage.getCourseReminderMinutes(), 30);
      expect(storage.getWearableNotificationCompatibility(), isTrue);
      expect(storage.getWidgetThemePreference(), 'dark');
      expect(storage.getWidgetFontScale(), 1.4);
      expect(storage.getWidgetBackgroundAlpha(), 0.65);
      expect(storage.getWidgetBackgroundColor(), 0xFFABCDEF);
      expect(storage.getLastCustomWidgetBackgroundColor(), 0xFFABCDEF);
      expect(storage.getWidgetBackgroundPath(), '/tmp/widget-light.jpg');
      expect(storage.getWidgetDarkBackgroundPath(), '/tmp/widget-dark.jpg');
      expect(storage.getWidgetUseLightBackgroundInDarkMode(), isTrue);
      expect(storage.getWidgetTextColor(), 0xFF123456);
      expect(storage.getLastCustomWidgetTextColor(), 0xFF123456);
      expect(storage.getWidgetTextOpacity(), 0.75);
      expect(storage.getWidgetHideTeacher(), isTrue);
      expect(storage.getWidgetHideLocation(), isTrue);
      expect(storage.getWidgetHideDate(), isTrue);
      expect(storage.getTimetableHideTeacher(), isFalse);
      expect(storage.getTimetableHideTeacherBrackets(), isFalse);
      expect(storage.getTimetableAddBlankLineAfterTitle(), isTrue);
      expect(storage.getTimetableDashedBorderDensity(), 1.5);
      expect(storage.getTimetablePageTextColor(), 0xFF111111);
      expect(storage.getTimetableLastCustomPageTextColor(), isNull);
      expect(storage.getTimetableCourseTextColor(), 0xFF222222);
      expect(storage.getTimetableLastCustomCourseTextColor(), 0xFF232323);
      expect(storage.getTimetableCourseBorderColor(), 0xFF333333);
      expect(storage.getTimetableLastCustomCourseBorderColor(), 0xFF343434);
      expect(storage.getTimetableBackgroundPath(), '/tmp/background.jpg');
      expect(
        storage.getTimetableDarkBackgroundPath(),
        '/tmp/background-dark.jpg',
      );
      expect(storage.getTimetableUseLightBackgroundInDarkMode(), isTrue);
      expect(storage.getPageBackgroundColor(), 'teal');
      expect(storage.getToastOpacity(), 0.8);
      expect(storage.getTimetableGridOpacity(), 0.42);
      expect(storage.getTimetableGridLineColor(), 0xFF454545);
      expect(storage.getTimetableLastCustomGridLineColor(), 0xFF464646);
      expect(storage.getTimetableGridLineWidth(), 1.5);
      expect(storage.getTimetableCourseTextSize(), 14);
      expect(storage.getTimetableTimeTextSize(), 10);
      expect(storage.getTimetableDateTextSize(), 13);
      expect(storage.getTimetableCourseBorderWidth(), 1.2);
      expect(storage.getTimetableCourseBorderOpacity(), 0.35);
      expect(storage.getShowTimetableGridLines(), isFalse);
      expect(storage.getShowTodayGridLines(), isFalse);
      expect(storage.getTimetableTodayLineColor(), 0xFF565656);
      expect(storage.getTimetableLastCustomTodayLineColor(), 0xFF575757);
      expect(storage.getTimetableTodayLineWidth(), 2.5);
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

    test('clamps widget style settings', () async {
      await storage.setWidgetFontScale(5);
      await storage.setWidgetBackgroundAlpha(-1);

      expect(storage.getWidgetFontScale(), 2.0);
      expect(storage.getWidgetBackgroundAlpha(), 0.0);
    });

    test('preserves fine-grained timetable course layout values', () async {
      await storage.setTimetableCourseFontScale(1.05);
      await storage.setTimetableCourseInnerPadding(2.5);
      await storage.setTimetableCourseOuterPadding(1.5);

      expect(storage.getTimetableCourseFontScale(), 1.05);
      expect(storage.getTimetableCourseInnerPadding(), 2.5);
      expect(storage.getTimetableCourseOuterPadding(), 1.5);
    });

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

    test('resets appearance defaults while retaining custom colors', () async {
      await storage.setThemePreference('dark');
      await storage.setThemeColor('blue');
      await storage.setCustomThemeColor(0xFF203040);
      await storage.setLastCustomThemeColor(0xFF203040);
      await storage.setTimetableBackgroundPath('/tmp/background.jpg');
      await storage.setTimetableDarkBackgroundPath('/tmp/background-dark.jpg');
      await storage.setTimetableUseLightBackgroundInDarkMode(true);
      await storage.setPageBackgroundColor('teal');
      await storage.setCustomPageBackgroundColor(0xFF102030);
      await storage.setLastCustomPageBackgroundColor(0xFF102030);
      await storage.setTimetablePageTextColor(0xFF111111);
      await storage.setTimetableLastCustomPageTextColor(0xFF121212);
      await storage.setTimetableCourseTextColor(0xFF232323);
      await storage.setTimetableLastCustomCourseTextColor(0xFF232323);
      await storage.setTimetableCourseBorderColor(0xFF333333);
      await storage.setTimetableLastCustomCourseBorderColor(0xFF343434);
      await storage.setTimetableGridOpacity(0.9);
      await storage.setTimetableGridLineColor(0xFF464646);
      await storage.setTimetableLastCustomGridLineColor(0xFF464646);
      await storage.setTimetableGridLineWidth(1.5);
      await storage.setTimetableCourseTextSize(16);
      await storage.setTimetableTimeTextSize(15);
      await storage.setTimetableDateTextSize(14);
      await storage.setTimetableCourseBorderWidth(2);
      await storage.setTimetableCourseBorderOpacity(0.2);
      await storage.setShowTimetableGridLines(false);
      await storage.setShowTodayGridLines(true);
      await storage.setTimetableTodayLineColor(0xFF575757);
      await storage.setTimetableLastCustomTodayLineColor(0xFF575757);
      await storage.setTimetableTodayLineWidth(2.5);
      await storage.setWidgetThemePreference('dark');
      await storage.setWidgetFontScale(1.5);
      await storage.setWidgetBackgroundAlpha(0.4);
      await storage.setWidgetBackgroundColor(0xFFABCDEF);
      await storage.setLastCustomWidgetBackgroundColor(0xFFABCDEF);
      await storage.setWidgetBackgroundPath('/tmp/widget-light.jpg');
      await storage.setWidgetDarkBackgroundPath('/tmp/widget-dark.jpg');
      await storage.setWidgetUseLightBackgroundInDarkMode(true);
      await storage.setWidgetTextColor(0xFF123456);
      await storage.setLastCustomWidgetTextColor(0xFF654321);
      await storage.setToastOpacity(0.8);
      await storage.setWidgetTextOpacity(0.75);
      await storage.setWidgetHideTeacher(true);
      await storage.setWidgetHideLocation(true);
      await storage.setWidgetHideDate(true);
      await storage.setTimetableHideTeacher(false);
      await storage.setTimetableHideTeacherBrackets(false);
      await storage.setTimetableAddBlankLineAfterTitle(true);
      await storage.setTimetableDashedBorderDensity(1.8);
      await storage.setCourseReminderEnabled(true);

      await storage.resetTimetableAppearance();

      expect(storage.getThemePreference(), isNull);
      expect(storage.getThemeColor(), isNull);
      expect(storage.getCustomThemeColor(), isNull);
      expect(storage.getLastCustomThemeColor(), 0xFF203040);
      expect(storage.getTimetableBackgroundPath(), isNull);
      expect(storage.getTimetableDarkBackgroundPath(), isNull);
      expect(storage.getTimetableUseLightBackgroundInDarkMode(), isTrue);
      expect(storage.getPageBackgroundColor(), isNull);
      expect(storage.getCustomPageBackgroundColor(), 0xFF102030);
      expect(storage.getLastCustomPageBackgroundColor(), 0xFF102030);
      expect(storage.getTimetablePageTextColor(), isNull);
      expect(storage.getTimetableLastCustomPageTextColor(), 0xFF121212);
      expect(storage.getTimetableCourseTextColor(), 0xFF232323);
      expect(storage.getTimetableLastCustomCourseTextColor(), 0xFF232323);
      expect(storage.getTimetableCourseBorderColor(), isNull);
      expect(storage.getTimetableLastCustomCourseBorderColor(), 0xFF343434);
      expect(storage.getTimetableGridOpacity(), 0.5);
      expect(storage.getTimetableGridLineColor(), 0xFF464646);
      expect(storage.getTimetableLastCustomGridLineColor(), 0xFF464646);
      expect(storage.getTimetableGridLineWidth(), 0.5);
      expect(storage.getTimetableCourseTextSize(), 12);
      expect(storage.getTimetableTimeTextSize(), 11);
      expect(storage.getTimetableDateTextSize(), 12);
      expect(storage.getTimetableCourseBorderWidth(), 0.5);
      expect(storage.getTimetableCourseBorderOpacity(), 0.7);
      expect(storage.getShowTimetableGridLines(), isTrue);
      expect(storage.getShowTodayGridLines(), isFalse);
      expect(storage.getTimetableTodayLineColor(), 0xFF575757);
      expect(storage.getTimetableLastCustomTodayLineColor(), 0xFF575757);
      expect(storage.getTimetableTodayLineWidth(), 1.0);
      expect(storage.getWidgetThemePreference(), isNull);
      expect(storage.getWidgetFontScale(), 1.0);
      expect(storage.getWidgetBackgroundAlpha(), 1.0);
      expect(storage.getWidgetBackgroundColor(), 0xFFABCDEF);
      expect(storage.getWidgetBackgroundPath(), isNull);
      expect(storage.getWidgetDarkBackgroundPath(), isNull);
      expect(storage.getWidgetUseLightBackgroundInDarkMode(), isTrue);
      expect(storage.getWidgetTextColor(), isNull);
      expect(storage.getLastCustomWidgetBackgroundColor(), 0xFFABCDEF);
      expect(storage.getLastCustomWidgetTextColor(), 0xFF654321);
      expect(storage.getWidgetTextOpacity(), 1.0);
      expect(storage.getToastOpacity(), 1.0);
      expect(storage.getWidgetHideTeacher(), isFalse);
      expect(storage.getWidgetHideLocation(), isFalse);
      expect(storage.getWidgetHideDate(), isFalse);
      expect(storage.getTimetableHideTeacher(), isTrue);
      expect(storage.getTimetableHideTeacherBrackets(), isTrue);
      expect(storage.getTimetableAddBlankLineAfterTitle(), isFalse);
      expect(storage.getTimetableDashedBorderDensity(), 1.0);
      expect(storage.getCourseReminderEnabled(), isTrue);
    });
  });
}
