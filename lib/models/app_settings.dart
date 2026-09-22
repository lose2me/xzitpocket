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

enum AppServiceFeature {
  campusCard('campus_card', '一卡通查询'),
  power('power', '电费查询'),
  exams('exams', '考试查询'),
  academic('academic', '学业情况'),
  network('network', '网络管理'),
  repair('repair', '极速报修'),
  learning('learning', '学习中心'),
  calendar('calendar', '学校校历'),
  teacherEvaluation('teacher_evaluation', '教师评价');

  final String storageValue;
  final String title;

  const AppServiceFeature(this.storageValue, this.title);
}

class AppSettings {
  final AppThemePreference themePreference;
  final AppThemeColor themeColor;
  final ClassAutomationMode classAutomationMode;
  final String? timetableBackgroundPath;
  final double timetableBackgroundOpacity;
  final double timetableComponentOpacity;
  final double timetableGridOpacity;
  final bool showTimetableGridLines;
  final bool showTodayGridLines;
  final Set<AppServiceFeature> hiddenServiceFeatures;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.themeColor = AppThemeColor.rose,
    this.classAutomationMode = ClassAutomationMode.off,
    this.timetableBackgroundPath,
    this.timetableBackgroundOpacity = 0.5,
    this.timetableComponentOpacity = 0.7,
    this.timetableGridOpacity = 0.5,
    this.showTimetableGridLines = true,
    this.showTodayGridLines = false,
    this.hiddenServiceFeatures = const {},
  });

  static const _unset = Object();

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AppThemeColor? themeColor,
    ClassAutomationMode? classAutomationMode,
    Object? timetableBackgroundPath = _unset,
    double? timetableBackgroundOpacity,
    double? timetableComponentOpacity,
    double? timetableGridOpacity,
    bool? showTimetableGridLines,
    bool? showTodayGridLines,
    Set<AppServiceFeature>? hiddenServiceFeatures,
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
      timetableGridOpacity: timetableGridOpacity ?? this.timetableGridOpacity,
      showTimetableGridLines:
          showTimetableGridLines ?? this.showTimetableGridLines,
      showTodayGridLines: showTodayGridLines ?? this.showTodayGridLines,
      hiddenServiceFeatures:
          hiddenServiceFeatures ?? this.hiddenServiceFeatures,
    );
  }
}
