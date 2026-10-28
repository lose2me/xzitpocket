import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../utils/course_text_template.dart';

/// 课程改动（假/调）文字标记在日期栏内的位置。
enum TimetableDayMarkerPosition {
  topRight,
  bottomRight,
  topLeft,
  bottomLeft;

  String get storageValue => name;

  static TimetableDayMarkerPosition fromStorage(String? value) {
    return TimetableDayMarkerPosition.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => TimetableDayMarkerPosition.topRight,
    );
  }
}

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
  blue(Color(0xFF2563EB), Color(0xFF8AB4FF), '海蓝'),
  rose(Color(0xFFBE185D), Color(0xFFFF8DB7), '玫红'),
  green(Color(0xFF15803D), Color(0xFF7BE495), '翠绿'),
  orange(Color(0xFFC2410C), Color(0xFFFFB36B), '暖橙'),
  purple(Color(0xFF7C3AED), Color(0xFFC4A1FF), '罗兰紫'),
  teal(Color(0xFF0F766E), Color(0xFF5EEAD4), '青碧');

  final Color lightColor;
  final Color darkColor;
  final String label;

  const AppThemeColor(this.lightColor, this.darkColor, this.label);

  /// The light color is used when no brightness context is available.
  Color get color => lightColor;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? darkColor : lightColor;

  String get storageValue => name;

  static AppThemeColor fromStorage(String? value) {
    return AppThemeColor.values.firstWhere(
      (item) => item.storageValue == value,
      orElse: () => AppThemeColor.teal,
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
      orElse: () => TimetableBorderType.none,
    );
  }
}

enum AppPageBackgroundColor {
  neutral(Color(0xFFF4F6F8), Color(0xFF12171C), '雾灰'),
  blue(Color(0xFFF1F5FF), Color(0xFF111D33), '浅蓝'),
  teal(Color(0xFFEDF9F7), Color(0xFF0D2927), '青绿'),
  green(Color(0xFFF1FAF3), Color(0xFF132619), '浅绿'),
  rose(Color(0xFFFFF3F7), Color(0xFF321522), '浅红'),
  purple(Color(0xFFF7F3FF), Color(0xFF211735), '淡紫');

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
  exams('exams', '考试安排'),
  academic('academic', '学业情况'),
  network('network', '网络管理'),
  repair('repair', '极速报修'),
  learning('learning', '资源中心'),
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
  final double toastOpacity;
  final ClassAutomationMode classAutomationMode;
  final bool courseReminderEnabled;
  final int courseReminderMinutes;
  final bool wearableNotificationCompatibility;
  final WidgetThemePreference widgetThemePreference;
  final double widgetFontScale;
  final double widgetBackgroundAlpha;
  final double widgetTextOpacity;
  final Color? widgetBackgroundColor;
  final Color? lastCustomWidgetBackgroundColor;
  final String? widgetBackgroundPath;
  final String? widgetDarkBackgroundPath;
  final bool widgetUseLightBackgroundInDarkMode;
  final Color? widgetTextColor;
  final Color? lastCustomWidgetTextColor;
  final bool widgetHideTeacher;
  final bool widgetHideLocation;
  final bool widgetHideDate;
  final double timetableSectionHeight;

  /// 用户是否显式设置过课节高度。未设置时课表按可用高度自适应，
  /// 一页正好显示 [kAdaptiveSectionCount] 个可见课节。
  final bool timetableSectionHeightIsCustom;
  final double timetableTimeColumnWidth;
  final double timetableDayHeaderHeight;
  final double timetableCourseCornerRadius;
  final double timetableCourseInnerPadding;
  final double timetableCourseOuterPadding;
  final double timetableCourseAlpha;
  final String timetableCourseTextTemplate;
  final double timetableDashedBorderDensity;
  final bool timetableHideSectionTime;
  final bool timetableHideDateUnderDay;
  final bool timetableDayColorMarkers;
  final bool timetableDayTextMarkers;
  final TimetableDayMarkerPosition timetableDayTextMarkerPosition;
  final double timetableDayTextMarkerPadding;
  final double timetableCountdownBarLengthRatio;
  final bool timetableCountdownBarRounded;
  final bool timetableTextAlignCenterHorizontal;
  final bool timetableTextAlignCenterVertical;
  final TimetableBorderType timetableBorderType;
  final Color? timetablePageTextColor;
  final Color? timetableLastCustomPageTextColor;
  final double timetablePageTextOpacity;
  final Color? timetableCourseBorderColor;
  final Color? timetableLastCustomCourseBorderColor;
  final String? timetableBackgroundPath;
  final String? timetableDarkBackgroundPath;
  final bool timetableUseLightBackgroundInDarkMode;
  final AppPageBackgroundColor? pageBackgroundColor;
  final double timetableGridOpacity;
  final Color? timetableGridLineColor;
  final Color? timetableLastCustomGridLineColor;
  final double timetableGridLineWidth;
  final double timetableCourseTextSize;
  final double timetableCourseTextOpacity;
  final double timetableTimeTextSize;
  final double timetableDateTextSize;
  final double timetableDayTextMarkerSize;
  final double timetableCourseBorderWidth;
  final double timetableCourseBorderOpacity;
  final bool showTimetableGridLines;
  final bool showTodayGridLines;
  final Color? timetableTodayLineColor;
  final Color? timetableLastCustomTodayLineColor;
  final double timetableTodayLineWidth;
  final double timetableTodayLineOpacity;
  final bool showTodayHorizontalGridLines;

  /// 是否在当前周页面显示其他周的课程。
  final bool showNonCurrentWeekCourses;

  /// 当前时间线：从左侧时间栏延伸出的贯通横线，仅在 8:00-21:20 显示。
  final bool showCurrentTimeLine;

  final double timetableCountdownBarThickness;
  final double timetableCountdownBarTopPadding;
  final double timetableCountdownBarBottomPadding;
  final bool useCloudTimetableAdjustments;
  final Set<AppServiceFeature> hiddenServiceFeatures;

  const AppSettings({
    this.themePreference = AppThemePreference.system,
    this.themeColor = AppThemeColor.teal,
    this.customThemeColor,
    this.lastCustomThemeColor,
    this.customPageBackgroundColor,
    this.lastCustomPageBackgroundColor,
    this.toastOpacity = 1.0,
    this.classAutomationMode = ClassAutomationMode.off,
    this.courseReminderEnabled = false,
    this.courseReminderMinutes = 15,
    this.wearableNotificationCompatibility = false,
    this.widgetThemePreference = WidgetThemePreference.system,
    this.widgetFontScale = 1.0,
    this.widgetBackgroundAlpha = 1.0,
    this.widgetTextOpacity = 1.0,
    this.widgetBackgroundColor,
    this.lastCustomWidgetBackgroundColor,
    this.widgetBackgroundPath,
    this.widgetDarkBackgroundPath,
    this.widgetUseLightBackgroundInDarkMode = true,
    this.widgetTextColor,
    this.lastCustomWidgetTextColor,
    this.widgetHideTeacher = false,
    this.widgetHideLocation = false,
    this.widgetHideDate = false,
    this.timetableSectionHeight = 60.0,
    this.timetableSectionHeightIsCustom = false,
    this.timetableTimeColumnWidth = 40.0,
    this.timetableDayHeaderHeight = 40.0,
    this.timetableCourseCornerRadius = 6.0,
    this.timetableCourseInnerPadding = 2.0,
    this.timetableCourseOuterPadding = 2.0,
    this.timetableCourseAlpha = 1.0,
    this.timetableCourseTextTemplate = kDefaultCourseTextTemplate,
    this.timetableDashedBorderDensity = 1.0,
    this.timetableHideSectionTime = false,
    this.timetableHideDateUnderDay = false,
    this.timetableDayColorMarkers = true,
    this.timetableDayTextMarkers = true,
    this.timetableDayTextMarkerPosition = TimetableDayMarkerPosition.topRight,
    this.timetableDayTextMarkerPadding = 2.0,
    this.timetableCountdownBarLengthRatio = 0.75,
    this.timetableCountdownBarRounded = true,
    this.timetableCountdownBarThickness = 3.0,
    this.timetableCountdownBarTopPadding = 0.0,
    this.timetableCountdownBarBottomPadding = 4.0,
    this.showCurrentTimeLine = false,
    this.timetableTextAlignCenterHorizontal = false,
    this.timetableTextAlignCenterVertical = false,
    this.timetableBorderType = TimetableBorderType.none,
    this.timetablePageTextColor,
    this.timetableLastCustomPageTextColor,
    this.timetablePageTextOpacity = 1.0,
    this.timetableCourseBorderColor,
    this.timetableLastCustomCourseBorderColor,
    this.timetableBackgroundPath,
    this.timetableDarkBackgroundPath,
    this.timetableUseLightBackgroundInDarkMode = true,
    this.pageBackgroundColor,
    this.timetableGridOpacity = 0.5,
    this.timetableGridLineColor,
    this.timetableLastCustomGridLineColor,
    this.timetableGridLineWidth = 0.5,
    this.timetableCourseTextSize = 11.4,
    this.timetableCourseTextOpacity = 1.0,
    this.timetableTimeTextSize = 11.0,
    this.timetableDateTextSize = 12.0,
    this.timetableDayTextMarkerSize = 8.0,
    this.timetableCourseBorderWidth = 0.5,
    this.timetableCourseBorderOpacity = 0.7,
    this.showTimetableGridLines = true,
    this.showTodayGridLines = true,
    this.timetableTodayLineColor,
    this.timetableLastCustomTodayLineColor,
    this.timetableTodayLineWidth = 1.5,
    this.timetableTodayLineOpacity = 0.5,
    this.showTodayHorizontalGridLines = false,
    this.showNonCurrentWeekCourses = false,
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
    double? toastOpacity,
    ClassAutomationMode? classAutomationMode,
    bool? courseReminderEnabled,
    int? courseReminderMinutes,
    bool? wearableNotificationCompatibility,
    WidgetThemePreference? widgetThemePreference,
    double? widgetFontScale,
    double? widgetBackgroundAlpha,
    double? widgetTextOpacity,
    Object? widgetBackgroundColor = _unset,
    Object? lastCustomWidgetBackgroundColor = _unset,
    Object? widgetBackgroundPath = _unset,
    Object? widgetDarkBackgroundPath = _unset,
    bool? widgetUseLightBackgroundInDarkMode,
    Object? widgetTextColor = _unset,
    Object? lastCustomWidgetTextColor = _unset,
    bool? widgetHideTeacher,
    bool? widgetHideLocation,
    bool? widgetHideDate,
    double? timetableSectionHeight,
    bool? timetableSectionHeightIsCustom,
    double? timetableTimeColumnWidth,
    double? timetableDayHeaderHeight,
    double? timetableCourseCornerRadius,
    double? timetableCourseInnerPadding,
    double? timetableCourseOuterPadding,
    double? timetableCourseAlpha,
    String? timetableCourseTextTemplate,
    double? timetableDashedBorderDensity,
    bool? timetableHideSectionTime,
    bool? timetableHideDateUnderDay,
    bool? timetableDayColorMarkers,
    bool? timetableDayTextMarkers,
    TimetableDayMarkerPosition? timetableDayTextMarkerPosition,
    double? timetableDayTextMarkerPadding,
    double? timetableCountdownBarLengthRatio,
    bool? timetableCountdownBarRounded,
    double? timetableCountdownBarThickness,
    double? timetableCountdownBarTopPadding,
    double? timetableCountdownBarBottomPadding,
    bool? showCurrentTimeLine,
    bool? timetableTextAlignCenterHorizontal,
    bool? timetableTextAlignCenterVertical,
    TimetableBorderType? timetableBorderType,
    Object? timetablePageTextColor = _unset,
    Object? timetableLastCustomPageTextColor = _unset,
    double? timetablePageTextOpacity,
    Object? timetableCourseBorderColor = _unset,
    Object? timetableLastCustomCourseBorderColor = _unset,
    Object? timetableBackgroundPath = _unset,
    Object? timetableDarkBackgroundPath = _unset,
    bool? timetableUseLightBackgroundInDarkMode,
    Object? pageBackgroundColor = _unset,
    double? timetableGridOpacity,
    Object? timetableGridLineColor = _unset,
    Object? timetableLastCustomGridLineColor = _unset,
    double? timetableGridLineWidth,
    double? timetableCourseTextSize,
    double? timetableCourseTextOpacity,
    double? timetableTimeTextSize,
    double? timetableDateTextSize,
    double? timetableDayTextMarkerSize,
    double? timetableCourseBorderWidth,
    double? timetableCourseBorderOpacity,
    bool? showTimetableGridLines,
    bool? showTodayGridLines,
    Object? timetableTodayLineColor = _unset,
    Object? timetableLastCustomTodayLineColor = _unset,
    double? timetableTodayLineWidth,
    double? timetableTodayLineOpacity,
    bool? showTodayHorizontalGridLines,
    bool? showNonCurrentWeekCourses,
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
      toastOpacity: toastOpacity ?? this.toastOpacity,
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
      widgetBackgroundColor: identical(widgetBackgroundColor, _unset)
          ? this.widgetBackgroundColor
          : widgetBackgroundColor as Color?,
      lastCustomWidgetBackgroundColor:
          identical(lastCustomWidgetBackgroundColor, _unset)
          ? this.lastCustomWidgetBackgroundColor
          : lastCustomWidgetBackgroundColor as Color?,
      widgetBackgroundPath: identical(widgetBackgroundPath, _unset)
          ? this.widgetBackgroundPath
          : widgetBackgroundPath as String?,
      widgetDarkBackgroundPath: identical(widgetDarkBackgroundPath, _unset)
          ? this.widgetDarkBackgroundPath
          : widgetDarkBackgroundPath as String?,
      widgetUseLightBackgroundInDarkMode:
          widgetUseLightBackgroundInDarkMode ??
          this.widgetUseLightBackgroundInDarkMode,
      widgetTextColor: identical(widgetTextColor, _unset)
          ? this.widgetTextColor
          : widgetTextColor as Color?,
      lastCustomWidgetTextColor: identical(lastCustomWidgetTextColor, _unset)
          ? this.lastCustomWidgetTextColor
          : lastCustomWidgetTextColor as Color?,
      widgetHideTeacher: widgetHideTeacher ?? this.widgetHideTeacher,
      widgetHideLocation: widgetHideLocation ?? this.widgetHideLocation,
      widgetHideDate: widgetHideDate ?? this.widgetHideDate,
      timetableSectionHeight:
          timetableSectionHeight ?? this.timetableSectionHeight,
      timetableSectionHeightIsCustom:
          timetableSectionHeightIsCustom ?? this.timetableSectionHeightIsCustom,
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
      timetableCourseTextTemplate:
          timetableCourseTextTemplate ?? this.timetableCourseTextTemplate,
      timetableDashedBorderDensity:
          timetableDashedBorderDensity ?? this.timetableDashedBorderDensity,
      timetableHideSectionTime:
          timetableHideSectionTime ?? this.timetableHideSectionTime,
      timetableHideDateUnderDay:
          timetableHideDateUnderDay ?? this.timetableHideDateUnderDay,
      timetableDayColorMarkers:
          timetableDayColorMarkers ?? this.timetableDayColorMarkers,
      timetableDayTextMarkers:
          timetableDayTextMarkers ?? this.timetableDayTextMarkers,
      timetableDayTextMarkerPosition:
          timetableDayTextMarkerPosition ?? this.timetableDayTextMarkerPosition,
      timetableDayTextMarkerPadding:
          timetableDayTextMarkerPadding ?? this.timetableDayTextMarkerPadding,
      timetableCountdownBarLengthRatio:
          timetableCountdownBarLengthRatio ??
          this.timetableCountdownBarLengthRatio,
      timetableCountdownBarRounded:
          timetableCountdownBarRounded ?? this.timetableCountdownBarRounded,
      timetableCountdownBarThickness:
          timetableCountdownBarThickness ?? this.timetableCountdownBarThickness,
      timetableCountdownBarTopPadding:
          timetableCountdownBarTopPadding ??
          this.timetableCountdownBarTopPadding,
      timetableCountdownBarBottomPadding:
          timetableCountdownBarBottomPadding ??
          this.timetableCountdownBarBottomPadding,
      showCurrentTimeLine: showCurrentTimeLine ?? this.showCurrentTimeLine,
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
      timetableDayTextMarkerSize:
          timetableDayTextMarkerSize ?? this.timetableDayTextMarkerSize,
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
      showTodayHorizontalGridLines:
          showTodayHorizontalGridLines ?? this.showTodayHorizontalGridLines,
      showNonCurrentWeekCourses:
          showNonCurrentWeekCourses ?? this.showNonCurrentWeekCourses,
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

  String? widgetBackgroundFor(Brightness brightness) {
    if (brightness == Brightness.dark && !widgetUseLightBackgroundInDarkMode) {
      return widgetDarkBackgroundPath;
    }
    return widgetBackgroundPath;
  }

  Color? pageBackgroundFor(Brightness brightness) =>
      customPageBackgroundColor ?? pageBackgroundColor?.resolve(brightness);

  /// Resolves a built-in timetable page-text swatch for the active theme.
  /// Custom colors remain fixed user choices.
  Color? timetablePageTextFor(Brightness brightness) {
    final value = timetablePageTextColor;
    if (value == null) return null;
    for (final color in AppThemeColor.values) {
      if (value.toARGB32() == color.lightColor.toARGB32()) {
        return color.resolve(brightness);
      }
    }
    return value;
  }

  /// B1：按「参考设备」比例把与空间、字号相关的课表尺寸换算成当前设备的实际值。
  /// 存储与滑杆始终使用参考值（在参考设备上即真实 px），因此同一份设置会在各
  /// 设备上按比例呈现。颜色、不透明度、圆角、线宽、虚线密度保持绝对，不缩放。
  /// 仅用于用户显式设置过的尺寸；未设置时课节高度走自适应默认。
  AppSettings scaledForViewport(Size viewport) {
    if (viewport.isEmpty) return this;
    final scale = timetableViewportScale(viewport);
    // Course-card metrics are deliberately NOT scaled here: the grid scales
    // them from the actual cell box (width/height, 5/7 columns) instead.
    return copyWith(
      timetableSectionHeight: timetableSectionHeight * scale.y,
      timetableDayHeaderHeight: timetableDayHeaderHeight * scale.y,
      timetableTimeColumnWidth: timetableTimeColumnWidth * scale.x,
      timetableTimeTextSize: timetableTimeTextSize * scale.text,
      timetableDateTextSize: timetableDateTextSize * scale.text,
      timetableDayTextMarkerSize: timetableDayTextMarkerSize * scale.text,
      timetableDayTextMarkerPadding: timetableDayTextMarkerPadding * scale.text,
      timetableGridLineWidth: timetableGridLineWidth * scale.text,
      timetableTodayLineWidth: timetableTodayLineWidth * scale.text,
    );
  }
}

/// 比例缩放（B1）的参考设备逻辑尺寸。
const kReferenceViewport = Size(390, 844);

/// 参考比例的最小/最大缩放，避免小屏过小、平板过大。
const kMinUiScale = 0.85;
const kMaxUiScale = 1.3;

/// 每页正好显示的可见课节行数（隐藏的 5、6 节不计入）。
const kAdaptiveSectionCount = 9;

/// 课表或布局测量算出的真实自适应课节高度（未自定义时写入），
/// 设置页据此显示默认值与滑杆默认线。
final ValueNotifier<double?> measuredAdaptiveSectionHeight =
    ValueNotifier<double?>(null);

/// 自适应课节高度的估算值：可用高度 / [kAdaptiveSectionCount]，
/// 作为尚未拿到真实布局测量前的兜底。
double estimateAdaptiveSectionHeight({double dayHeaderHeight = 40.0}) {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return 60.0;
    final scale = view.devicePixelRatio;
    final size = view.physicalSize / scale;
    final padding = view.viewPadding;
    // 周头部 + 日期栏 + 底部导航内容；状态栏与手势条已由 padding 扣除。
    final chromeHeight = 54.0 + (dayHeaderHeight + 1.0) + 50.0;
    final available =
        size.height -
        padding.top / scale -
        padding.bottom / scale -
        chromeHeight;
    if (!available.isFinite || available <= 0) return 60.0;
    return (available / kAdaptiveSectionCount).toDouble();
  } catch (_) {
    return 60.0;
  }
}

/// 当前设备相对参考设备的课表尺寸比例（B1）。
({double x, double y, double text}) timetableViewportScale(Size viewport) {
  double clampScale(double value) =>
      value.clamp(kMinUiScale, kMaxUiScale).toDouble();
  final x = clampScale(viewport.width / kReferenceViewport.width);
  final y = clampScale(viewport.height / kReferenceViewport.height);
  // 字号跟随较小的一维，保证文字始终能放进课节/单元格，不会溢出。
  final text = x < y ? x : y;
  return (x: x, y: y, text: text);
}

/// 参考课块尺寸：390×844、5 列、默认字号/padding 下的单格大小。
const kReferenceCourseCellWidth = 68.0;
const kReferenceCourseCellHeight = 60.0;
const kMinCellScale = 0.8;
const kMaxCellScale = 1.4;

/// 课块内部（文字、padding、圆角、边框、倒计时条）的相对缩放。
/// 用实际格子的宽高而不是整个窗口，5/7 列和不同可用高度都会自动适配。
double timetableCellScale({
  required double cellWidth,
  required double cellHeight,
}) {
  if (!cellWidth.isFinite ||
      !cellHeight.isFinite ||
      cellWidth <= 0 ||
      cellHeight <= 0) {
    return 1.0;
  }
  final scale = math.min(
    cellWidth / kReferenceCourseCellWidth,
    cellHeight / kReferenceCourseCellHeight,
  );
  return scale.clamp(kMinCellScale, kMaxCellScale).toDouble();
}
