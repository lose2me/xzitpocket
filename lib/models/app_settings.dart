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
  blue(Color(0xFF2563EB), Color(0xFF60A5FA), '海蓝'),
  rose(Color(0xFFBE123C), Color(0xFFFB7185), '玫红'),
  green(Color(0xFF047857), Color(0xFF34D399), '翠绿'),
  orange(Color(0xFFC2410C), Color(0xFFFB923C), '暖橙'),
  purple(Color(0xFF7C3AED), Color(0xFFA78BFA), '罗兰紫'),
  teal(Color(0xFF0F766E), Color(0xFF2DD4BF), '青碧');

  final Color lightColor;
  final Color darkColor;
  final String label;

  const AppThemeColor(this.lightColor, this.darkColor, this.label);

  /// The light color remains the canonical swatch for compatibility with
  /// places that do not have a brightness context.
  Color get color => lightColor;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;

  String get storageValue => name;

  static AppThemeColor fromStorage(String? value) {
    return AppThemeColor.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AppThemeColor.rose,
    );
  }
}

enum WidgetThemePreference {
  system,
  light,
  dark;

  String get storageValue => name;

  static WidgetThemePreference fromStorage(String? value) {
    return WidgetThemePreference.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => WidgetThemePreference.system,
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
  final bool courseReminderEnabled;
  final int courseReminderMinutes;
  final bool wearableNotificationCompatibility;
  final WidgetThemePreference widgetThemePreference;
  final double widgetFontScale;
  final double widgetBackgroundAlpha;
  final bool widgetHideTeacher;
  final bool widgetHideLocation;
  final bool widgetHideDate;
  final String? timetableBackgroundPath;
  final double timetableComponentOpacity;
  final double timetableGridOpacity;
  final double timetableCourseTextSize;
  final double timetableTimeTextSize;
  final double timetableDateTextSize;
  final double timetableCourseBorderWidth;
  final double timetableCourseBorderOpacity;
  final bool showTimetableGridLines;
  final bool showTodayGridLines;
  final bool useCloudTimetableAdjustments;
  final Set<AppServiceFeature> hiddenServiceFeatures;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.themeColor = AppThemeColor.rose,
    this.classAutomationMode = ClassAutomationMode.off,
    this.courseReminderEnabled = false,
    this.courseReminderMinutes = 15,
    this.wearableNotificationCompatibility = false,
    this.widgetThemePreference = WidgetThemePreference.system,
    this.widgetFontScale = 1.0,
    this.widgetBackgroundAlpha = 1.0,
    this.widgetHideTeacher = false,
    this.widgetHideLocation = false,
    this.widgetHideDate = false,
    this.timetableBackgroundPath,
    this.timetableComponentOpacity = 0.6,
    this.timetableGridOpacity = 0.7,
    this.timetableCourseTextSize = 12.0,
    this.timetableTimeTextSize = 11.0,
    this.timetableDateTextSize = 12.0,
    this.timetableCourseBorderWidth = 0.5,
    this.timetableCourseBorderOpacity = 0.6,
    this.showTimetableGridLines = true,
    this.showTodayGridLines = false,
    this.useCloudTimetableAdjustments = true,
    this.hiddenServiceFeatures = const {},
  });

  static const _unset = Object();

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AppThemeColor? themeColor,
    ClassAutomationMode? classAutomationMode,
    bool? courseReminderEnabled,
    int? courseReminderMinutes,
    bool? wearableNotificationCompatibility,
    WidgetThemePreference? widgetThemePreference,
    double? widgetFontScale,
    double? widgetBackgroundAlpha,
    bool? widgetHideTeacher,
    bool? widgetHideLocation,
    bool? widgetHideDate,
    Object? timetableBackgroundPath = _unset,
    double? timetableComponentOpacity,
    double? timetableGridOpacity,
    double? timetableCourseTextSize,
    double? timetableTimeTextSize,
    double? timetableDateTextSize,
    double? timetableCourseBorderWidth,
    double? timetableCourseBorderOpacity,
    bool? showTimetableGridLines,
    bool? showTodayGridLines,
    bool? useCloudTimetableAdjustments,
    Set<AppServiceFeature>? hiddenServiceFeatures,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      themeColor: themeColor ?? this.themeColor,
      classAutomationMode: classAutomationMode ?? this.classAutomationMode,
      courseReminderEnabled:
          courseReminderEnabled ?? this.courseReminderEnabled,
      courseReminderMinutes:
          courseReminderMinutes ?? this.courseReminderMinutes,
      wearableNotificationCompatibility:
          wearableNotificationCompatibility ??
          this.wearableNotificationCompatibility,
      widgetThemePreference:
          widgetThemePreference ?? this.widgetThemePreference,
      widgetFontScale: widgetFontScale ?? this.widgetFontScale,
      widgetBackgroundAlpha:
          widgetBackgroundAlpha ?? this.widgetBackgroundAlpha,
      widgetHideTeacher: widgetHideTeacher ?? this.widgetHideTeacher,
      widgetHideLocation: widgetHideLocation ?? this.widgetHideLocation,
      widgetHideDate: widgetHideDate ?? this.widgetHideDate,
      timetableBackgroundPath: identical(timetableBackgroundPath, _unset)
          ? this.timetableBackgroundPath
          : timetableBackgroundPath as String?,
      timetableComponentOpacity:
          timetableComponentOpacity ?? this.timetableComponentOpacity,
      timetableGridOpacity: timetableGridOpacity ?? this.timetableGridOpacity,
      timetableCourseTextSize:
          timetableCourseTextSize ?? this.timetableCourseTextSize,
      timetableTimeTextSize:
          timetableTimeTextSize ?? this.timetableTimeTextSize,
      timetableDateTextSize:
          timetableDateTextSize ?? this.timetableDateTextSize,
      timetableCourseBorderWidth:
          timetableCourseBorderWidth ?? this.timetableCourseBorderWidth,
      timetableCourseBorderOpacity:
          timetableCourseBorderOpacity ?? this.timetableCourseBorderOpacity,
      showTimetableGridLines:
          showTimetableGridLines ?? this.showTimetableGridLines,
      showTodayGridLines: showTodayGridLines ?? this.showTodayGridLines,
      useCloudTimetableAdjustments:
          useCloudTimetableAdjustments ?? this.useCloudTimetableAdjustments,
      hiddenServiceFeatures:
          hiddenServiceFeatures ?? this.hiddenServiceFeatures,
    );
  }
}
