import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/app_settings.dart';

void main() {
  group('AppThemePreference', () {
    test('fromStorage returns correct values', () {
      expect(
        AppThemePreference.fromStorage('system'),
        AppThemePreference.system,
      );
      expect(AppThemePreference.fromStorage('light'), AppThemePreference.light);
      expect(AppThemePreference.fromStorage('dark'), AppThemePreference.dark);
    });

    test('fromStorage returns system for unknown value', () {
      expect(
        AppThemePreference.fromStorage('invalid'),
        AppThemePreference.system,
      );
      expect(AppThemePreference.fromStorage(null), AppThemePreference.system);
    });

    test('themeMode maps correctly', () {
      expect(AppThemePreference.system.themeMode, ThemeMode.system);
      expect(AppThemePreference.light.themeMode, ThemeMode.light);
      expect(AppThemePreference.dark.themeMode, ThemeMode.dark);
    });

    test('storageValue roundtrips', () {
      for (final pref in AppThemePreference.values) {
        expect(AppThemePreference.fromStorage(pref.storageValue), pref);
      }
    });
  });

  group('AppThemeColor', () {
    test('offers six Material tonal presets', () {
      expect(AppThemeColor.values, hasLength(6));
    });

    test('fromStorage returns correct values', () {
      for (final color in AppThemeColor.values) {
        expect(AppThemeColor.fromStorage(color.storageValue), color);
      }
    });

    test('fromStorage returns rose for unknown value', () {
      expect(AppThemeColor.fromStorage('invalid'), AppThemeColor.rose);
      expect(AppThemeColor.fromStorage(null), AppThemeColor.rose);
    });
  });

  group('ClassAutomationMode', () {
    test('fromStorage returns correct values', () {
      expect(ClassAutomationMode.fromStorage('off'), ClassAutomationMode.off);
      expect(ClassAutomationMode.fromStorage('dnd'), ClassAutomationMode.dnd);
      expect(
        ClassAutomationMode.fromStorage('dnd_keep'),
        ClassAutomationMode.dndKeep,
      );
    });

    test('fromStorage returns off for unknown value', () {
      expect(
        ClassAutomationMode.fromStorage('invalid'),
        ClassAutomationMode.off,
      );
      expect(ClassAutomationMode.fromStorage(null), ClassAutomationMode.off);
    });

    test('storageValue roundtrips', () {
      for (final mode in ClassAutomationMode.values) {
        expect(ClassAutomationMode.fromStorage(mode.storageValue), mode);
      }
    });
  });

  group('AppSettings', () {
    test('defaults are correct', () {
      const settings = AppSettings();
      expect(settings.themePreference, AppThemePreference.system);
      expect(settings.themeColor, AppThemeColor.rose);
      expect(settings.customThemeColor, isNull);
      expect(settings.lastCustomThemeColor, isNull);
      expect(settings.toastOpacity, 1.0);
      expect(settings.classAutomationMode, ClassAutomationMode.off);
      expect(settings.courseReminderEnabled, isFalse);
      expect(settings.courseReminderMinutes, 15);
      expect(settings.wearableNotificationCompatibility, isFalse);
      expect(settings.widgetThemePreference, WidgetThemePreference.system);
      expect(settings.widgetFontScale, 1.0);
      expect(settings.widgetBackgroundAlpha, 1.0);
      expect(settings.widgetBackgroundColor, isNull);
      expect(settings.widgetBackgroundPath, isNull);
      expect(settings.widgetDarkBackgroundPath, isNull);
      expect(settings.widgetUseLightBackgroundInDarkMode, isFalse);
      expect(settings.widgetTextColor, isNull);
      expect(settings.widgetTextOpacity, 1.0);
      expect(settings.widgetHideTeacher, isFalse);
      expect(settings.widgetHideLocation, isFalse);
      expect(settings.widgetHideDate, isFalse);
      expect(settings.timetableHideTeacher, isTrue);
      expect(settings.timetableHideTeacherBrackets, isTrue);
      expect(settings.timetableBackgroundPath, isNull);
      expect(settings.timetableDarkBackgroundPath, isNull);
      expect(settings.timetableUseLightBackgroundInDarkMode, isFalse);
      expect(settings.pageBackgroundColor, isNull);
      expect(settings.timetableCourseCornerRadius, 6.0);
      expect(settings.timetableCourseInnerPadding, 2.0);
      expect(settings.timetableCourseOuterPadding, 1.8);
      expect(settings.timetableComponentOpacity, 0.7);
      expect(settings.timetableGridOpacity, 0.5);
      expect(settings.timetableGridLineColor, isNull);
      expect(settings.timetableGridLineWidth, 0.5);
      expect(settings.timetableCourseTextSize, 12.0);
      expect(settings.timetableTimeTextSize, 11.0);
      expect(settings.timetableDateTextSize, 12.0);
      expect(settings.timetableCourseBorderWidth, 0.5);
      expect(settings.timetableCourseBorderOpacity, 0.7);
      expect(settings.timetableCourseBorderColor, isNull);
      expect(settings.showTimetableGridLines, isTrue);
      expect(settings.showTodayGridLines, isFalse);
      expect(settings.timetableTodayLineColor, isNull);
      expect(settings.timetableTodayLineWidth, 1.0);
      expect(settings.hiddenServiceFeatures, isEmpty);
    });

    test('copyWith overrides specified fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        themePreference: AppThemePreference.dark,
        themeColor: AppThemeColor.blue,
        customThemeColor: const Color(0xFF123456),
        lastCustomThemeColor: const Color(0xFF654321),
        toastOpacity: 0.8,
        courseReminderEnabled: true,
        courseReminderMinutes: 30,
        wearableNotificationCompatibility: true,
        widgetThemePreference: WidgetThemePreference.dark,
        widgetFontScale: 1.4,
        widgetBackgroundAlpha: 0.65,
        widgetBackgroundColor: const Color(0xFFABCDEF),
        lastCustomWidgetBackgroundColor: const Color(0xFFABCDEF),
        widgetBackgroundPath: '/tmp/widget-light.jpg',
        widgetDarkBackgroundPath: '/tmp/widget-dark.jpg',
        widgetUseLightBackgroundInDarkMode: true,
        widgetTextColor: const Color(0xFF123456),
        lastCustomWidgetTextColor: const Color(0xFF123456),
        widgetTextOpacity: 0.75,
        widgetHideTeacher: true,
        widgetHideLocation: true,
        widgetHideDate: true,
        timetableHideTeacher: false,
        timetableHideTeacherBrackets: false,
        timetableBackgroundPath: '/tmp/background.jpg',
        timetableDarkBackgroundPath: '/tmp/background-dark.jpg',
        timetableUseLightBackgroundInDarkMode: true,
        pageBackgroundColor: AppPageBackgroundColor.teal,
        timetablePageTextColor: const Color(0xFF111111),
        timetableLastCustomPageTextColor: const Color(0xFF121212),
        timetableCourseTextColor: const Color(0xFF222222),
        timetableLastCustomCourseTextColor: const Color(0xFF232323),
        timetableCourseBorderColor: const Color(0xFF333333),
        timetableLastCustomCourseBorderColor: const Color(0xFF343434),
        timetableComponentOpacity: 0.7,
        timetableGridOpacity: 0.45,
        timetableGridLineColor: const Color(0xFF454545),
        timetableLastCustomGridLineColor: const Color(0xFF464646),
        timetableGridLineWidth: 1.5,
        timetableCourseTextSize: 14,
        timetableTimeTextSize: 10,
        timetableDateTextSize: 13,
        timetableCourseBorderWidth: 1.2,
        timetableCourseBorderOpacity: 0.35,
        showTimetableGridLines: false,
        showTodayGridLines: false,
        timetableTodayLineColor: const Color(0xFF565656),
        timetableLastCustomTodayLineColor: const Color(0xFF575757),
        timetableTodayLineWidth: 2.5,
        hiddenServiceFeatures: {
          AppServiceFeature.power,
          AppServiceFeature.teacherEvaluation,
        },
      );
      expect(updated.themePreference, AppThemePreference.dark);
      expect(updated.themeColor, AppThemeColor.blue);
      expect(updated.customThemeColor, const Color(0xFF123456));
      expect(updated.lastCustomThemeColor, const Color(0xFF654321));
      expect(updated.toastOpacity, 0.8);
      expect(updated.classAutomationMode, ClassAutomationMode.off);
      expect(updated.courseReminderEnabled, isTrue);
      expect(updated.courseReminderMinutes, 30);
      expect(updated.wearableNotificationCompatibility, isTrue);
      expect(updated.widgetThemePreference, WidgetThemePreference.dark);
      expect(updated.widgetFontScale, 1.4);
      expect(updated.widgetBackgroundAlpha, 0.65);
      expect(updated.widgetBackgroundColor, const Color(0xFFABCDEF));
      expect(updated.widgetBackgroundPath, '/tmp/widget-light.jpg');
      expect(updated.widgetDarkBackgroundPath, '/tmp/widget-dark.jpg');
      expect(updated.widgetUseLightBackgroundInDarkMode, isTrue);
      expect(updated.widgetTextColor, const Color(0xFF123456));
      expect(updated.widgetTextOpacity, 0.75);
      expect(updated.widgetHideTeacher, isTrue);
      expect(updated.widgetHideLocation, isTrue);
      expect(updated.widgetHideDate, isTrue);
      expect(updated.timetableHideTeacher, isFalse);
      expect(updated.timetableHideTeacherBrackets, isFalse);
      expect(updated.timetableBackgroundPath, '/tmp/background.jpg');
      expect(updated.timetableDarkBackgroundPath, '/tmp/background-dark.jpg');
      expect(updated.timetableUseLightBackgroundInDarkMode, isTrue);
      expect(updated.pageBackgroundColor, AppPageBackgroundColor.teal);
      expect(updated.timetablePageTextColor, const Color(0xFF111111));
      expect(updated.timetableLastCustomPageTextColor, const Color(0xFF121212));
      expect(updated.timetableCourseTextColor, const Color(0xFF222222));
      expect(
        updated.timetableLastCustomCourseTextColor,
        const Color(0xFF232323),
      );
      expect(updated.timetableCourseBorderColor, const Color(0xFF333333));
      expect(
        updated.timetableLastCustomCourseBorderColor,
        const Color(0xFF343434),
      );
      expect(updated.timetableComponentOpacity, 0.7);
      expect(updated.timetableGridOpacity, 0.45);
      expect(updated.timetableGridLineColor, const Color(0xFF454545));
      expect(updated.timetableLastCustomGridLineColor, const Color(0xFF464646));
      expect(updated.timetableGridLineWidth, 1.5);
      expect(updated.timetableCourseTextSize, 14);
      expect(updated.timetableTimeTextSize, 10);
      expect(updated.timetableDateTextSize, 13);
      expect(updated.timetableCourseBorderWidth, 1.2);
      expect(updated.timetableCourseBorderOpacity, 0.35);
      expect(updated.showTimetableGridLines, isFalse);
      expect(updated.showTodayGridLines, isFalse);
      expect(updated.timetableTodayLineColor, const Color(0xFF565656));
      expect(
        updated.timetableLastCustomTodayLineColor,
        const Color(0xFF575757),
      );
      expect(updated.timetableTodayLineWidth, 2.5);
      expect(updated.hiddenServiceFeatures, {
        AppServiceFeature.power,
        AppServiceFeature.teacherEvaluation,
      });
    });

    test('copyWith preserves unspecified fields', () {
      const settings = AppSettings(
        themePreference: AppThemePreference.light,
        classAutomationMode: ClassAutomationMode.dnd,
      );
      final updated = settings.copyWith(
        classAutomationMode: ClassAutomationMode.dndKeep,
      );
      expect(updated.themePreference, AppThemePreference.light);
      expect(updated.themeColor, AppThemeColor.rose);
      expect(updated.classAutomationMode, ClassAutomationMode.dndKeep);
      expect(updated.timetableBackgroundPath, isNull);
      expect(updated.timetableComponentOpacity, 0.7);
      expect(updated.showTimetableGridLines, isTrue);
    });

    test('copyWith can clear the background path', () {
      const settings = AppSettings(
        customThemeColor: Color(0xFF123456),
        lastCustomThemeColor: Color(0xFF654321),
        timetableBackgroundPath: '/tmp/bg.jpg',
        timetableDarkBackgroundPath: '/tmp/dark.jpg',
      );
      final updated = settings.copyWith(
        customThemeColor: null,
        lastCustomThemeColor: null,
        timetableBackgroundPath: null,
        timetableDarkBackgroundPath: null,
      );

      expect(updated.customThemeColor, isNull);
      expect(updated.lastCustomThemeColor, isNull);
      expect(updated.timetableBackgroundPath, isNull);
      expect(updated.timetableDarkBackgroundPath, isNull);
    });

    test('resolves separate light and dark timetable backgrounds', () {
      const settings = AppSettings(
        timetableBackgroundPath: '/tmp/light.jpg',
        timetableDarkBackgroundPath: '/tmp/dark.jpg',
      );

      expect(
        settings.timetableBackgroundFor(Brightness.light),
        '/tmp/light.jpg',
      );
      expect(settings.timetableBackgroundFor(Brightness.dark), '/tmp/dark.jpg');
      expect(
        settings
            .copyWith(timetableUseLightBackgroundInDarkMode: true)
            .timetableBackgroundFor(Brightness.dark),
        '/tmp/light.jpg',
      );
    });

    test('resolves separate light and dark widget backgrounds', () {
      const settings = AppSettings(
        widgetBackgroundPath: '/tmp/widget-light.jpg',
        widgetDarkBackgroundPath: '/tmp/widget-dark.jpg',
      );

      expect(
        settings.widgetBackgroundFor(Brightness.light),
        '/tmp/widget-light.jpg',
      );
      expect(
        settings.widgetBackgroundFor(Brightness.dark),
        '/tmp/widget-dark.jpg',
      );
      expect(
        settings
            .copyWith(widgetUseLightBackgroundInDarkMode: true)
            .widgetBackgroundFor(Brightness.dark),
        '/tmp/widget-light.jpg',
      );
    });

    test('resolves adaptive global page backgrounds', () {
      const settings = AppSettings(
        pageBackgroundColor: AppPageBackgroundColor.blue,
      );

      expect(
        settings.pageBackgroundFor(Brightness.light),
        AppPageBackgroundColor.blue.lightColor,
      );
      expect(
        settings.pageBackgroundFor(Brightness.dark),
        AppPageBackgroundColor.blue.darkColor,
      );
    });
  });
}
