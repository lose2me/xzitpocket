import 'package:flutter/material.dart';

enum AppThemePreference {
  system,
  light,
  dark;

  String get storageValue => name;

  ThemeMode get themeMode {
    return switch (this) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };
  }

  static AppThemePreference fromStorage(String? value) {
    return AppThemePreference.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

enum ClassAutomationMode {
  off,
  dnd,
  dndKeep;

  String get storageValue {
    return switch (this) {
      ClassAutomationMode.off => 'off',
      ClassAutomationMode.dnd => 'dnd',
      ClassAutomationMode.dndKeep => 'dnd_keep',
    };
  }

  static ClassAutomationMode fromStorage(String? value) {
    return ClassAutomationMode.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => ClassAutomationMode.off,
    );
  }
}

class AppSettings {
  final AppThemePreference themePreference;
  final ClassAutomationMode classAutomationMode;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.classAutomationMode = ClassAutomationMode.off,
  });

  AppSettings copyWith({
    AppThemePreference? themePreference,
    ClassAutomationMode? classAutomationMode,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      classAutomationMode: classAutomationMode ?? this.classAutomationMode,
    );
  }
}
