import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xzitpocket/models/app_settings.dart';

void main() {
  group('AppThemePreference', () {
    test('fromStorage returns correct values', () {
      expect(AppThemePreference.fromStorage('system'), AppThemePreference.system);
      expect(AppThemePreference.fromStorage('light'), AppThemePreference.light);
      expect(AppThemePreference.fromStorage('dark'), AppThemePreference.dark);
    });

    test('fromStorage returns system for unknown value', () {
      expect(AppThemePreference.fromStorage('invalid'), AppThemePreference.system);
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

  group('ClassAutomationMode', () {
    test('fromStorage returns correct values', () {
      expect(ClassAutomationMode.fromStorage('off'), ClassAutomationMode.off);
      expect(ClassAutomationMode.fromStorage('dnd'), ClassAutomationMode.dnd);
      expect(ClassAutomationMode.fromStorage('dnd_keep'), ClassAutomationMode.dndKeep);
    });

    test('fromStorage returns off for unknown value', () {
      expect(ClassAutomationMode.fromStorage('invalid'), ClassAutomationMode.off);
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
      expect(settings.classAutomationMode, ClassAutomationMode.off);
    });

    test('copyWith overrides specified fields', () {
      const settings = AppSettings();
      final updated = settings.copyWith(
        themePreference: AppThemePreference.dark,
      );
      expect(updated.themePreference, AppThemePreference.dark);
      expect(updated.classAutomationMode, ClassAutomationMode.off);
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
      expect(updated.classAutomationMode, ClassAutomationMode.dndKeep);
    });
  });
}
