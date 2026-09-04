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
      expect(settings.classAutomationMode, ClassAutomationMode.off);
      expect(settings.timetableBackgroundPath, isNull);
      expect(settings.timetableBackgroundOpacity, 0.24);
      expect(settings.timetableComponentOpacity, 0.85);
      expect(settings.showTimetableGridLines, isTrue);
    });

    test('copyWith overrides specified fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        themePreference: AppThemePreference.dark,
        themeColor: AppThemeColor.blue,
        timetableBackgroundPath: '/tmp/background.jpg',
        timetableBackgroundOpacity: 0.6,
        timetableComponentOpacity: 0.7,
        showTimetableGridLines: false,
      );
      expect(updated.themePreference, AppThemePreference.dark);
      expect(updated.themeColor, AppThemeColor.blue);
      expect(updated.classAutomationMode, ClassAutomationMode.off);
      expect(updated.timetableBackgroundPath, '/tmp/background.jpg');
      expect(updated.timetableBackgroundOpacity, 0.6);
      expect(updated.timetableComponentOpacity, 0.7);
      expect(updated.showTimetableGridLines, isFalse);
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
      expect(updated.timetableBackgroundOpacity, 0.24);
      expect(updated.timetableComponentOpacity, 0.85);
      expect(updated.showTimetableGridLines, isTrue);
    });

    test('copyWith can clear the background path', () {
      const settings = AppSettings(timetableBackgroundPath: '/tmp/bg.jpg');
      final updated = settings.copyWith(timetableBackgroundPath: null);

      expect(updated.timetableBackgroundPath, isNull);
    });
  });
}
