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

enum AppThemeColor {
  rose(Color(0xFFCE3C57), '玫红'),
  blue(Color(0xFF2F6FED), '蓝色'),
  green(Color(0xFF16845B), '绿色'),
  orange(Color(0xFFD96B16), '橙色'),
  purple(Color(0xFF7A4FD4), '紫色'),
  teal(Color(0xFF087F8C), '青色');

  final Color color;
  final String label;

  const AppThemeColor(this.color, this.label);

  String get storageValue => name;

  static AppThemeColor fromStorage(String? value) {
    return AppThemeColor.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AppThemeColor.rose,
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
  final AppThemeColor themeColor;
  final ClassAutomationMode classAutomationMode;
  final String? timetableBackgroundPath;
  final double timetableBackgroundOpacity;
  final double timetableComponentOpacity;
  final bool showTimetableGridLines;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.themeColor = AppThemeColor.rose,
    this.classAutomationMode = ClassAutomationMode.off,
    this.timetableBackgroundPath,
    this.timetableBackgroundOpacity = 0.24,
    this.timetableComponentOpacity = 0.85,
    this.showTimetableGridLines = true,
  });

  static const _unset = Object();

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AppThemeColor? themeColor,
    ClassAutomationMode? classAutomationMode,
    Object? timetableBackgroundPath = _unset,
    double? timetableBackgroundOpacity,
    double? timetableComponentOpacity,
    bool? showTimetableGridLines,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      themeColor: themeColor ?? this.themeColor,
      classAutomationMode: classAutomationMode ?? this.classAutomationMode,
      timetableBackgroundPath: identical(timetableBackgroundPath, _unset)
          ? this.timetableBackgroundPath
          : timetableBackgroundPath as String?,
      timetableBackgroundOpacity:
          timetableBackgroundOpacity ?? this.timetableBackgroundOpacity,
      timetableComponentOpacity:
          timetableComponentOpacity ?? this.timetableComponentOpacity,
      showTimetableGridLines:
          showTimetableGridLines ?? this.showTimetableGridLines,
    );
  }
}
