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
  blue(Color(0xFF415F91), Color(0xFFAAC7FF), '海蓝'),
  rose(Color(0xFF904A4A), Color(0xFFFFB3B3), '玫红'),
  green(Color(0xFF3F682E), Color(0xFFA4D88A), '翠绿'),
  orange(Color(0xFF8B5000), Color(0xFFFFB86D), '暖橙'),
  purple(Color(0xFF735085), Color(0xFFE0B6F2), '罗兰紫'),
  teal(Color(0xFF006A6A), Color(0xFF4FD8D8), '青碧');

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

enum TimetableBorderType {
  none,
  solid,
  dashed;

  String get storageValue => name;

  static TimetableBorderType fromStorage(String? value) {
    return TimetableBorderType.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => TimetableBorderType.solid,
    );
  }
}

enum AppPageBackgroundColor {
  neutral(Color(0xFFEEF2F6), Color(0xFF1B1F24), '雾灰'),
  blue(Color(0xFFE7EFFA), Color(0xFF172A46), '浅蓝'),
  teal(Color(0xFFDDEFEF), Color(0xFF123636), '青绿'),
  green(Color(0xFFE5F0E0), Color(0xFF1D3420), '浅绿'),
  rose(Color(0xFFF6E7E7), Color(0xFF3D2325), '浅红'),
  purple(Color(0xFFF0E7F4), Color(0xFF33263A), '淡紫');

  final Color lightColor;
  final Color darkColor;
  final String label;

  const AppPageBackgroundColor(this.lightColor, this.darkColor, this.label);

  String get storageValue => name;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;

  static AppPageBackgroundColor? fromStorage(String? value) {
    if (value == null) return null;
    for (final item in values) {
      if (item.storageValue == value) return item;
    }
    return null;
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
  final Color? customThemeColor;
  final Color? lastCustomThemeColor;
  final Color? customPageBackgroundColor;
  final Color? lastCustomPageBackgroundColor;
  final ClassAutomationMode classAutomationMode;
  final bool courseReminderEnabled;
  final int courseReminderMinutes;
  final bool wearableNotificationCompatibility;
  final WidgetThemePreference widgetThemePreference;
  final double widgetFontScale;
  final double widgetBackgroundAlpha;
  final double widgetTextOpacity;
  final bool widgetHideTeacher;
  final bool widgetHideLocation;
  final bool widgetHideDate;
  final double timetableSectionHeight;
  final double timetableTimeColumnWidth;
  final double timetableDayHeaderHeight;
  final double timetableCourseCornerRadius;
  final double timetableCourseInnerPadding;
  final double timetableCourseOuterPadding;
  final double timetableCourseAlpha;
  final double timetableCourseFontScale;
  final bool timetableHideSectionTime;
  final bool timetableHideDateUnderDay;
  final bool timetableShowStartTime;
  final bool timetableHideLocation;
  final bool timetableHideTeacher;
  final bool timetableHideTeacherBrackets;
  final bool timetableRemoveLocationAt;
  final bool timetableTextAlignCenterHorizontal;
  final bool timetableTextAlignCenterVertical;
  final TimetableBorderType timetableBorderType;
  final Color? timetablePageTextColor;
  final Color? timetableLastCustomPageTextColor;
  final double timetablePageTextOpacity;
  final Color? timetableCourseTextColor;
  final Color? timetableLastCustomCourseTextColor;
  final Color? timetableCourseBorderColor;
  final Color? timetableLastCustomCourseBorderColor;
  final String? timetableBackgroundPath;
  final String? timetableDarkBackgroundPath;
  final bool timetableUseLightBackgroundInDarkMode;
  final AppPageBackgroundColor? pageBackgroundColor;
  final double timetableComponentOpacity;
  final double timetableGridOpacity;
  final Color? timetableGridLineColor;
  final Color? timetableLastCustomGridLineColor;
  final double timetableGridLineWidth;
  final double timetableCourseTextSize;
  final double timetableCourseTextOpacity;
  final double timetableTimeTextSize;
  final double timetableDateTextSize;
  final double timetableCourseBorderWidth;
  final double timetableCourseBorderOpacity;
  final bool showTimetableGridLines;
  final bool showTodayGridLines;
  final Color? timetableTodayLineColor;
  final Color? timetableLastCustomTodayLineColor;
  final double timetableTodayLineWidth;
  final double timetableTodayLineOpacity;
  final bool useCloudTimetableAdjustments;
  final Set<AppServiceFeature> hiddenServiceFeatures;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.themeColor = AppThemeColor.rose,
    this.customThemeColor,
    this.lastCustomThemeColor,
    this.customPageBackgroundColor,
    this.lastCustomPageBackgroundColor,
    this.classAutomationMode = ClassAutomationMode.off,
    this.courseReminderEnabled = false,
    this.courseReminderMinutes = 15,
    this.wearableNotificationCompatibility = false,
    this.widgetThemePreference = WidgetThemePreference.system,
    this.widgetFontScale = 1.0,
    this.widgetBackgroundAlpha = 1.0,
    this.widgetTextOpacity = 1.0,
    this.widgetHideTeacher = false,
    this.widgetHideLocation = false,
    this.widgetHideDate = false,
    this.timetableSectionHeight = 70.0,
    this.timetableTimeColumnWidth = 40.0,
    this.timetableDayHeaderHeight = 45.0,
    this.timetableCourseCornerRadius = 6.0,
    this.timetableCourseInnerPadding = 2.0,
    this.timetableCourseOuterPadding = 1.8,
    this.timetableCourseAlpha = 1.0,
    this.timetableCourseFontScale = 1.0,
    this.timetableHideSectionTime = false,
    this.timetableHideDateUnderDay = false,
    this.timetableShowStartTime = false,
    this.timetableHideLocation = false,
    this.timetableHideTeacher = true,
    this.timetableHideTeacherBrackets = true,
    this.timetableRemoveLocationAt = false,
    this.timetableTextAlignCenterHorizontal = false,
    this.timetableTextAlignCenterVertical = false,
    this.timetableBorderType = TimetableBorderType.solid,
    this.timetablePageTextColor,
    this.timetableLastCustomPageTextColor,
    this.timetablePageTextOpacity = 1.0,
    this.timetableCourseTextColor,
    this.timetableLastCustomCourseTextColor,
    this.timetableCourseBorderColor,
    this.timetableLastCustomCourseBorderColor,
    this.timetableBackgroundPath,
    this.timetableDarkBackgroundPath,
    this.timetableUseLightBackgroundInDarkMode = false,
    this.pageBackgroundColor,
    this.timetableComponentOpacity = 0.7,
    this.timetableGridOpacity = 0.5,
    this.timetableGridLineColor,
    this.timetableLastCustomGridLineColor,
    this.timetableGridLineWidth = 0.5,
    this.timetableCourseTextSize = 12.0,
    this.timetableCourseTextOpacity = 1.0,
    this.timetableTimeTextSize = 11.0,
    this.timetableDateTextSize = 12.0,
    this.timetableCourseBorderWidth = 0.5,
    this.timetableCourseBorderOpacity = 0.7,
    this.showTimetableGridLines = true,
    this.showTodayGridLines = false,
    this.timetableTodayLineColor,
    this.timetableLastCustomTodayLineColor,
    this.timetableTodayLineWidth = 1.0,
    this.timetableTodayLineOpacity = 0.5,
    this.useCloudTimetableAdjustments = true,
    this.hiddenServiceFeatures = const {},
  });

  static const _unset = Object();

  AppSettings copyWith({
    AppThemePreference? themePreference,
    AppThemeColor? themeColor,
    Object? customThemeColor = _unset,
    Object? lastCustomThemeColor = _unset,
    Object? customPageBackgroundColor = _unset,
    Object? lastCustomPageBackgroundColor = _unset,
    ClassAutomationMode? classAutomationMode,
    bool? courseReminderEnabled,
    int? courseReminderMinutes,
    bool? wearableNotificationCompatibility,
    WidgetThemePreference? widgetThemePreference,
    double? widgetFontScale,
    double? widgetBackgroundAlpha,
    double? widgetTextOpacity,
    bool? widgetHideTeacher,
    bool? widgetHideLocation,
    bool? widgetHideDate,
    double? timetableSectionHeight,
    double? timetableTimeColumnWidth,
    double? timetableDayHeaderHeight,
    double? timetableCourseCornerRadius,
    double? timetableCourseInnerPadding,
    double? timetableCourseOuterPadding,
    double? timetableCourseAlpha,
    double? timetableCourseFontScale,
    bool? timetableHideSectionTime,
    bool? timetableHideDateUnderDay,
    bool? timetableShowStartTime,
    bool? timetableHideLocation,
    bool? timetableHideTeacher,
    bool? timetableHideTeacherBrackets,
    bool? timetableRemoveLocationAt,
    bool? timetableTextAlignCenterHorizontal,
    bool? timetableTextAlignCenterVertical,
    TimetableBorderType? timetableBorderType,
    Object? timetablePageTextColor = _unset,
    Object? timetableLastCustomPageTextColor = _unset,
    double? timetablePageTextOpacity,
    Object? timetableCourseTextColor = _unset,
    Object? timetableLastCustomCourseTextColor = _unset,
    Object? timetableCourseBorderColor = _unset,
    Object? timetableLastCustomCourseBorderColor = _unset,
    Object? timetableBackgroundPath = _unset,
    Object? timetableDarkBackgroundPath = _unset,
    bool? timetableUseLightBackgroundInDarkMode,
    Object? pageBackgroundColor = _unset,
    double? timetableComponentOpacity,
    double? timetableGridOpacity,
    Object? timetableGridLineColor = _unset,
    Object? timetableLastCustomGridLineColor = _unset,
    double? timetableGridLineWidth,
    double? timetableCourseTextSize,
    double? timetableCourseTextOpacity,
    double? timetableTimeTextSize,
    double? timetableDateTextSize,
    double? timetableCourseBorderWidth,
    double? timetableCourseBorderOpacity,
    bool? showTimetableGridLines,
    bool? showTodayGridLines,
    Object? timetableTodayLineColor = _unset,
    Object? timetableLastCustomTodayLineColor = _unset,
    double? timetableTodayLineWidth,
    double? timetableTodayLineOpacity,
    bool? useCloudTimetableAdjustments,
    Set<AppServiceFeature>? hiddenServiceFeatures,
  }) {
    return AppSettings(
      themePreference: themePreference ?? this.themePreference,
      themeColor: themeColor ?? this.themeColor,
      customThemeColor: identical(customThemeColor, _unset)
          ? this.customThemeColor
          : customThemeColor as Color?,
      lastCustomThemeColor: identical(lastCustomThemeColor, _unset)
          ? this.lastCustomThemeColor
          : lastCustomThemeColor as Color?,
      customPageBackgroundColor: identical(customPageBackgroundColor, _unset)
          ? this.customPageBackgroundColor
          : customPageBackgroundColor as Color?,
      lastCustomPageBackgroundColor:
          identical(lastCustomPageBackgroundColor, _unset)
          ? this.lastCustomPageBackgroundColor
          : lastCustomPageBackgroundColor as Color?,
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
      widgetTextOpacity: widgetTextOpacity ?? this.widgetTextOpacity,
      widgetHideTeacher: widgetHideTeacher ?? this.widgetHideTeacher,
      widgetHideLocation: widgetHideLocation ?? this.widgetHideLocation,
      widgetHideDate: widgetHideDate ?? this.widgetHideDate,
      timetableSectionHeight:
          timetableSectionHeight ?? this.timetableSectionHeight,
      timetableTimeColumnWidth:
          timetableTimeColumnWidth ?? this.timetableTimeColumnWidth,
      timetableDayHeaderHeight:
          timetableDayHeaderHeight ?? this.timetableDayHeaderHeight,
      timetableCourseCornerRadius:
          timetableCourseCornerRadius ?? this.timetableCourseCornerRadius,
      timetableCourseInnerPadding:
          timetableCourseInnerPadding ?? this.timetableCourseInnerPadding,
      timetableCourseOuterPadding:
          timetableCourseOuterPadding ?? this.timetableCourseOuterPadding,
      timetableCourseAlpha: timetableCourseAlpha ?? this.timetableCourseAlpha,
      timetableCourseFontScale:
          timetableCourseFontScale ?? this.timetableCourseFontScale,
      timetableHideSectionTime:
          timetableHideSectionTime ?? this.timetableHideSectionTime,
      timetableHideDateUnderDay:
          timetableHideDateUnderDay ?? this.timetableHideDateUnderDay,
      timetableShowStartTime:
          timetableShowStartTime ?? this.timetableShowStartTime,
      timetableHideLocation:
          timetableHideLocation ?? this.timetableHideLocation,
      timetableHideTeacher: timetableHideTeacher ?? this.timetableHideTeacher,
      timetableHideTeacherBrackets:
          timetableHideTeacherBrackets ?? this.timetableHideTeacherBrackets,
      timetableRemoveLocationAt:
          timetableRemoveLocationAt ?? this.timetableRemoveLocationAt,
      timetableTextAlignCenterHorizontal:
          timetableTextAlignCenterHorizontal ??
          this.timetableTextAlignCenterHorizontal,
      timetableTextAlignCenterVertical:
          timetableTextAlignCenterVertical ??
          this.timetableTextAlignCenterVertical,
      timetableBorderType: timetableBorderType ?? this.timetableBorderType,
      timetablePageTextColor: identical(timetablePageTextColor, _unset)
          ? this.timetablePageTextColor
          : timetablePageTextColor as Color?,
      timetableLastCustomPageTextColor:
          identical(timetableLastCustomPageTextColor, _unset)
          ? this.timetableLastCustomPageTextColor
          : timetableLastCustomPageTextColor as Color?,
      timetablePageTextOpacity:
          timetablePageTextOpacity ?? this.timetablePageTextOpacity,
      timetableCourseTextColor: identical(timetableCourseTextColor, _unset)
          ? this.timetableCourseTextColor
          : timetableCourseTextColor as Color?,
      timetableLastCustomCourseTextColor:
          identical(timetableLastCustomCourseTextColor, _unset)
          ? this.timetableLastCustomCourseTextColor
          : timetableLastCustomCourseTextColor as Color?,
      timetableCourseBorderColor: identical(timetableCourseBorderColor, _unset)
          ? this.timetableCourseBorderColor
          : timetableCourseBorderColor as Color?,
      timetableLastCustomCourseBorderColor:
          identical(timetableLastCustomCourseBorderColor, _unset)
          ? this.timetableLastCustomCourseBorderColor
          : timetableLastCustomCourseBorderColor as Color?,
      timetableBackgroundPath: identical(timetableBackgroundPath, _unset)
          ? this.timetableBackgroundPath
          : timetableBackgroundPath as String?,
      timetableDarkBackgroundPath:
          identical(timetableDarkBackgroundPath, _unset)
          ? this.timetableDarkBackgroundPath
          : timetableDarkBackgroundPath as String?,
      timetableUseLightBackgroundInDarkMode:
          timetableUseLightBackgroundInDarkMode ??
          this.timetableUseLightBackgroundInDarkMode,
      pageBackgroundColor: identical(pageBackgroundColor, _unset)
          ? this.pageBackgroundColor
          : pageBackgroundColor as AppPageBackgroundColor?,
      timetableComponentOpacity:
          timetableComponentOpacity ?? this.timetableComponentOpacity,
      timetableGridOpacity: timetableGridOpacity ?? this.timetableGridOpacity,
      timetableGridLineColor: identical(timetableGridLineColor, _unset)
          ? this.timetableGridLineColor
          : timetableGridLineColor as Color?,
      timetableLastCustomGridLineColor:
          identical(timetableLastCustomGridLineColor, _unset)
          ? this.timetableLastCustomGridLineColor
          : timetableLastCustomGridLineColor as Color?,
      timetableGridLineWidth:
          timetableGridLineWidth ?? this.timetableGridLineWidth,
      timetableCourseTextSize:
          timetableCourseTextSize ?? this.timetableCourseTextSize,
      timetableCourseTextOpacity:
          timetableCourseTextOpacity ?? this.timetableCourseTextOpacity,
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
      timetableTodayLineColor: identical(timetableTodayLineColor, _unset)
          ? this.timetableTodayLineColor
          : timetableTodayLineColor as Color?,
      timetableLastCustomTodayLineColor:
          identical(timetableLastCustomTodayLineColor, _unset)
          ? this.timetableLastCustomTodayLineColor
          : timetableLastCustomTodayLineColor as Color?,
      timetableTodayLineWidth:
          timetableTodayLineWidth ?? this.timetableTodayLineWidth,
      timetableTodayLineOpacity:
          timetableTodayLineOpacity ?? this.timetableTodayLineOpacity,
      useCloudTimetableAdjustments:
          useCloudTimetableAdjustments ?? this.useCloudTimetableAdjustments,
      hiddenServiceFeatures:
          hiddenServiceFeatures ?? this.hiddenServiceFeatures,
    );
  }

  String? timetableBackgroundFor(Brightness brightness) {
    if (brightness == Brightness.dark &&
        !timetableUseLightBackgroundInDarkMode) {
      return timetableDarkBackgroundPath;
    }
    return timetableBackgroundPath;
  }

  Color? pageBackgroundFor(Brightness brightness) =>
      customPageBackgroundColor ?? pageBackgroundColor?.resolve(brightness);
}
