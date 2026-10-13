import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../utils/course_text_template.dart';
import '../services/native_automation_service.dart';
import '../services/preferences_storage.dart';
import '../services/widget_service.dart';
import 'config_provider.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  late PreferencesStorage _storage;

  @override
  AppSettings build() {
    _storage = ref.watch(preferencesStorageProvider);
    final customThemeColor = _storage.getCustomThemeColor();
    final customPageBackgroundColor = _storage.getCustomPageBackgroundColor();
    final pageTextColor = _storage.getTimetablePageTextColor();
    if (_storage.getLastCustomThemeColor() == null &&
        customThemeColor != null) {
      unawaited(_storage.setLastCustomThemeColor(customThemeColor));
    }
    if (_storage.getTimetableLastCustomPageTextColor() == null &&
        pageTextColor != null) {
      unawaited(_storage.setTimetableLastCustomPageTextColor(pageTextColor));
    }
    unawaited(NativeAutomationService.refreshClassAutomation());
    unawaited(NativeAutomationService.refreshCourseReminders());
    return AppSettings(
      themePreference: AppThemePreference.fromStorage(
        _storage.getThemePreference(),
      ),
      themeColor: AppThemeColor.fromStorage(_storage.getThemeColor()),
      customThemeColor: customThemeColor == null
          ? null
          : Color(customThemeColor),
      lastCustomThemeColor:
          (_storage.getLastCustomThemeColor() ?? customThemeColor) == null
          ? null
          : Color(_storage.getLastCustomThemeColor() ?? customThemeColor!),
      customPageBackgroundColor: customPageBackgroundColor == null
          ? null
          : Color(customPageBackgroundColor),
      lastCustomPageBackgroundColor:
          (_storage.getLastCustomPageBackgroundColor() ??
                  customPageBackgroundColor) ==
              null
          ? null
          : Color(
              _storage.getLastCustomPageBackgroundColor() ??
                  customPageBackgroundColor!,
            ),
      toastOpacity: _storage.getToastOpacity(),
      classAutomationMode: ClassAutomationMode.fromStorage(
        _storage.getClassAutomationMode(),
      ),
      courseReminderEnabled: _storage.getCourseReminderEnabled(),
      courseReminderMinutes: _storage.getCourseReminderMinutes(),
      wearableNotificationCompatibility: _storage
          .getWearableNotificationCompatibility(),
      widgetThemePreference: WidgetThemePreference.fromStorage(
        _storage.getWidgetThemePreference(),
      ),
      widgetFontScale: _storage.getWidgetFontScale(),
      widgetBackgroundAlpha: _storage.getWidgetBackgroundAlpha(),
      widgetTextOpacity: _storage.getWidgetTextOpacity(),
      widgetBackgroundColor: _storage.getWidgetBackgroundColor() == null
          ? null
          : Color(_storage.getWidgetBackgroundColor()!),
      lastCustomWidgetBackgroundColor:
          _storage.getLastCustomWidgetBackgroundColor() == null
          ? null
          : Color(_storage.getLastCustomWidgetBackgroundColor()!),
      widgetBackgroundPath: _storage.getWidgetBackgroundPath(),
      widgetDarkBackgroundPath: _storage.getWidgetDarkBackgroundPath(),
      widgetUseLightBackgroundInDarkMode: _storage
          .getWidgetUseLightBackgroundInDarkMode(),
      widgetTextColor: _storage.getWidgetTextColor() == null
          ? null
          : Color(_storage.getWidgetTextColor()!),
      lastCustomWidgetTextColor: _storage.getLastCustomWidgetTextColor() == null
          ? null
          : Color(_storage.getLastCustomWidgetTextColor()!),
      widgetHideTeacher: _storage.getWidgetHideTeacher(),
      widgetHideLocation: _storage.getWidgetHideLocation(),
      widgetHideDate: _storage.getWidgetHideDate(),
      // 无用户设置时使用自适应默认值（可用高度 / 11，见 estimateAdaptive…）。
      timetableSectionHeight: _storage.hasTimetableSectionHeight()
          ? _storage.getTimetableSectionHeight()
          : estimateAdaptiveSectionHeight(),
      timetableSectionHeightIsCustom: _storage.hasTimetableSectionHeight(),
      timetableTimeColumnWidth: _storage.getTimetableTimeColumnWidth(),
      timetableDayHeaderHeight: _storage.getTimetableDayHeaderHeight(),
      timetableCourseCornerRadius: _storage.getTimetableCourseCornerRadius(),
      timetableCourseInnerPadding: _storage.getTimetableCourseInnerPadding(),
      timetableCourseOuterPadding: _storage.getTimetableCourseOuterPadding(),
      timetableCourseAlpha: _storage.getTimetableCourseAlpha(),
      // 模板缺失时优先由旧布尔开关派生（未迁移安装），否则用默认模板。
      timetableCourseTextTemplate:
          _storage.getTimetableCourseTextTemplate() ??
          _storage.composeLegacyCourseTextTemplate() ??
          kDefaultCourseTextTemplate,
      timetableDashedBorderDensity: _storage.getTimetableDashedBorderDensity(),
      timetableHideSectionTime: _storage.getTimetableHideSectionTime(),
      timetableHideDateUnderDay: _storage.getTimetableHideDateUnderDay(),
      timetableDayColorMarkers: _storage.getTimetableDayColorMarkers(),
      timetableDayTextMarkers: _storage.getTimetableDayTextMarkers(),
      timetableDayTextMarkerPosition: TimetableDayMarkerPosition.fromStorage(
        _storage.getTimetableDayTextMarkerPosition(),
      ),
      timetableDayTextMarkerPadding: _storage
          .getTimetableDayTextMarkerPadding(),
      timetableCountdownBarLengthRatio: _storage
          .getTimetableCountdownBarLengthRatio(),
      timetableCountdownBarRounded: _storage.getTimetableCountdownBarRounded(),
      timetableCountdownBarThickness: _storage
          .getTimetableCountdownBarThickness(),
      timetableCountdownBarTopPadding: _storage
          .getTimetableCountdownBarTopPadding(),
      timetableCountdownBarBottomPadding: _storage
          .getTimetableCountdownBarBottomPadding(),
      showCurrentTimeLine: _storage.getShowCurrentTimeLine(),
      ignoreSystemTextScale: _storage.getIgnoreSystemTextScale(),
      timetableTextAlignCenterHorizontal: _storage
          .getTimetableTextAlignCenterHorizontal(),
      timetableTextAlignCenterVertical: _storage
          .getTimetableTextAlignCenterVertical(),
      timetableBorderType: TimetableBorderType.fromStorage(
        _storage.getTimetableBorderType(),
      ),
      timetablePageTextColor: pageTextColor == null
          ? null
          : Color(pageTextColor),
      timetableLastCustomPageTextColor:
          (_storage.getTimetableLastCustomPageTextColor() ?? pageTextColor) ==
              null
          ? null
          : Color(
              _storage.getTimetableLastCustomPageTextColor() ?? pageTextColor!,
            ),
      timetablePageTextOpacity: _storage.getTimetablePageTextOpacity(),
      timetableCourseBorderColor:
          _storage.getTimetableCourseBorderColor() == null
          ? null
          : Color(_storage.getTimetableCourseBorderColor()!),
      timetableLastCustomCourseBorderColor:
          _storage.getTimetableLastCustomCourseBorderColor() == null
          ? null
          : Color(_storage.getTimetableLastCustomCourseBorderColor()!),
      timetableBackgroundPath: _storage.getTimetableBackgroundPath(),
      timetableDarkBackgroundPath: _storage.getTimetableDarkBackgroundPath(),
      timetableUseLightBackgroundInDarkMode: _storage
          .getTimetableUseLightBackgroundInDarkMode(),
      pageBackgroundColor: AppPageBackgroundColor.fromStorage(
        _storage.getPageBackgroundColor(),
      ),
      timetableGridOpacity: _storage.getTimetableGridOpacity(),
      timetableGridLineColor: _storage.getTimetableGridLineColor() == null
          ? null
          : Color(_storage.getTimetableGridLineColor()!),
      timetableLastCustomGridLineColor:
          _storage.getTimetableLastCustomGridLineColor() == null
          ? null
          : Color(_storage.getTimetableLastCustomGridLineColor()!),
      timetableGridLineWidth: _storage.getTimetableGridLineWidth(),
      timetableCourseTextSize: _storage.getTimetableCourseTextSize(),
      timetableCourseTextOpacity: _storage.getTimetableCourseTextOpacity(),
      timetableTimeTextSize: _storage.getTimetableTimeTextSize(),
      timetableDateTextSize: _storage.getTimetableDateTextSize(),
      timetableDayTextMarkerSize: _storage.getTimetableDayTextMarkerSize(),
      timetableCourseBorderWidth: _storage.getTimetableCourseBorderWidth(),
      timetableCourseBorderOpacity: _storage.getTimetableCourseBorderOpacity(),
      showTimetableGridLines: _storage.getShowTimetableGridLines(),
      showTodayGridLines: _storage.getShowTodayGridLines(),
      timetableTodayLineColor: _storage.getTimetableTodayLineColor() == null
          ? null
          : Color(_storage.getTimetableTodayLineColor()!),
      timetableLastCustomTodayLineColor:
          _storage.getTimetableLastCustomTodayLineColor() == null
          ? null
          : Color(_storage.getTimetableLastCustomTodayLineColor()!),
      timetableTodayLineWidth: _storage.getTimetableTodayLineWidth(),
      timetableTodayLineOpacity: _storage.getTimetableTodayLineOpacity(),
      showTodayHorizontalGridLines: _storage.getShowTodayHorizontalGridLines(),
      useCloudTimetableAdjustments: _storage.getUseCloudTimetableAdjustments(),
      hiddenServiceFeatures: {
        for (final value in _storage.getHiddenServiceFeatures())
          ...AppServiceFeature.values.where(
            (feature) => feature.storageValue == value,
          ),
      },
    );
  }

  Future<void> setThemePreference(AppThemePreference preference) async {
    state = state.copyWith(themePreference: preference);
    await _storage.setThemePreference(preference.storageValue);
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Ignore widget refresh failures so theme changes still apply in-app.
    }
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    state = state.copyWith(themeColor: color, customThemeColor: null);
    await _storage.setThemeColor(color.storageValue);
    await _storage.setCustomThemeColor(null);
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Ignore widget refresh failures so theme changes still apply in-app.
    }
  }

  Future<void> setCustomThemeColor(Color color) async {
    state = state.copyWith(
      customThemeColor: color,
      lastCustomThemeColor: color,
    );
    await _storage.setCustomThemeColor(color.toARGB32());
    await _storage.setLastCustomThemeColor(color.toARGB32());
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Ignore widget refresh failures so theme changes still apply in-app.
    }
  }

  Future<void> setClassAutomationMode(ClassAutomationMode mode) async {
    state = state.copyWith(classAutomationMode: mode);
    await _storage.setClassAutomationMode(mode.storageValue);
    await NativeAutomationService.refreshClassAutomation();
  }

  Future<void> setCourseReminderEnabled(bool value) async {
    state = state.copyWith(courseReminderEnabled: value);
    await _storage.setCourseReminderEnabled(value);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setCourseReminderMinutes(int value) async {
    final normalized = value.clamp(1, 60);
    state = state.copyWith(courseReminderMinutes: normalized);
    await _storage.setCourseReminderMinutes(normalized);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setWearableNotificationCompatibility(bool value) async {
    state = state.copyWith(wearableNotificationCompatibility: value);
    await _storage.setWearableNotificationCompatibility(value);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setWidgetThemePreference(WidgetThemePreference value) async {
    state = state.copyWith(widgetThemePreference: value);
    await _storage.setWidgetThemePreference(value.storageValue);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetFontScale(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(widgetFontScale: normalized);
    await _storage.setWidgetFontScale(normalized);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetBackgroundAlpha(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(widgetBackgroundAlpha: normalized);
    await _storage.setWidgetBackgroundAlpha(normalized);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetTextOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(widgetTextOpacity: normalized);
    await _storage.setWidgetTextOpacity(normalized);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetBackgroundColor(Color? value) async {
    state = state.copyWith(widgetBackgroundColor: value);
    await _storage.setWidgetBackgroundColor(value?.toARGB32());
    await _refreshWidgetSettings();
  }

  Future<void> setCustomWidgetBackgroundColor(Color value) async {
    state = state.copyWith(
      widgetBackgroundColor: value,
      lastCustomWidgetBackgroundColor: value,
    );
    await _storage.setWidgetBackgroundColor(value.toARGB32());
    await _storage.setLastCustomWidgetBackgroundColor(value.toARGB32());
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetBackgroundPath(String? path) async {
    state = state.copyWith(widgetBackgroundPath: path);
    await _storage.setWidgetBackgroundPath(path);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetDarkBackgroundPath(String? path) async {
    state = state.copyWith(widgetDarkBackgroundPath: path);
    await _storage.setWidgetDarkBackgroundPath(path);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetUseLightBackgroundInDarkMode(bool value) async {
    state = state.copyWith(widgetUseLightBackgroundInDarkMode: value);
    await _storage.setWidgetUseLightBackgroundInDarkMode(value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetTextColor(Color? value) async {
    state = state.copyWith(widgetTextColor: value);
    await _storage.setWidgetTextColor(value?.toARGB32());
    await _refreshWidgetSettings();
  }

  Future<void> setCustomWidgetTextColor(Color value) async {
    state = state.copyWith(
      widgetTextColor: value,
      lastCustomWidgetTextColor: value,
    );
    await _storage.setWidgetTextColor(value.toARGB32());
    await _storage.setLastCustomWidgetTextColor(value.toARGB32());
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideTeacher(bool value) async {
    state = state.copyWith(widgetHideTeacher: value);
    await _storage.setWidgetHideTeacher(value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideLocation(bool value) async {
    state = state.copyWith(widgetHideLocation: value);
    await _storage.setWidgetHideLocation(value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideDate(bool value) async {
    state = state.copyWith(widgetHideDate: value);
    await _storage.setWidgetHideDate(value);
    await _refreshWidgetSettings();
  }

  Future<void> setTimetableSectionHeight(double value) async {
    final normalized = value.clamp(40.0, 140.0).toDouble();
    state = state.copyWith(
      timetableSectionHeight: normalized,
      timetableSectionHeightIsCustom: true,
    );
    await _storage.setTimetableSectionHeight(normalized);
  }

  Future<void> setTimetableTimeColumnWidth(double value) async {
    final normalized = value.clamp(20.0, 80.0).toDouble();
    state = state.copyWith(timetableTimeColumnWidth: normalized);
    await _storage.setTimetableTimeColumnWidth(normalized);
  }

  Future<void> setTimetableDayHeaderHeight(double value) async {
    final normalized = value.clamp(30.0, 80.0).toDouble();
    state = state.copyWith(timetableDayHeaderHeight: normalized);
    await _storage.setTimetableDayHeaderHeight(normalized);
  }

  Future<void> setTimetableCourseCornerRadius(double value) async {
    final normalized = value.clamp(0.0, 24.0).toDouble();
    state = state.copyWith(timetableCourseCornerRadius: normalized);
    await _storage.setTimetableCourseCornerRadius(normalized);
  }

  Future<void> setTimetableCourseInnerPadding(double value) async {
    final normalized = value.clamp(0.0, 12.0).toDouble();
    state = state.copyWith(timetableCourseInnerPadding: normalized);
    await _storage.setTimetableCourseInnerPadding(normalized);
  }

  Future<void> setTimetableCourseOuterPadding(double value) async {
    final normalized = value.clamp(0.0, 8.0).toDouble();
    state = state.copyWith(timetableCourseOuterPadding: normalized);
    await _storage.setTimetableCourseOuterPadding(normalized);
  }

  Future<void> setTimetableCourseAlpha(double value) async {
    final normalized = value.clamp(0.1, 1.0).toDouble();
    state = state.copyWith(timetableCourseAlpha: normalized);
    await _storage.setTimetableCourseAlpha(normalized);
  }

  Future<void> setTimetableCourseTextTemplate(String value) async {
    final normalized = value.trim();
    state = state.copyWith(
      timetableCourseTextTemplate: normalized.isEmpty
          ? kDefaultCourseTextTemplate
          : normalized,
    );
    await _storage.setTimetableCourseTextTemplate(
      normalized.isEmpty ? null : normalized,
    );
  }

  Future<void> setTimetableDashedBorderDensity(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(timetableDashedBorderDensity: normalized);
    await _storage.setTimetableDashedBorderDensity(normalized);
  }

  Future<void> setTimetableHideSectionTime(bool value) async {
    state = state.copyWith(timetableHideSectionTime: value);
    await _storage.setTimetableHideSectionTime(value);
  }

  Future<void> setTimetableHideDateUnderDay(bool value) async {
    state = state.copyWith(timetableHideDateUnderDay: value);
    await _storage.setTimetableHideDateUnderDay(value);
  }

  Future<void> setTimetableDayTextMarkerPosition(
    TimetableDayMarkerPosition value,
  ) async {
    state = state.copyWith(timetableDayTextMarkerPosition: value);
    await _storage.setTimetableDayTextMarkerPosition(value.storageValue);
  }

  Future<void> setTimetableDayTextMarkerPadding(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.0, 8.0);
    state = state.copyWith(timetableDayTextMarkerPadding: normalized);
    await _storage.setTimetableDayTextMarkerPadding(normalized);
  }

  Future<void> setTimetableCountdownBarLengthRatio(double value) async {
    final normalized = value.clamp(0.1, 1.0).toDouble();
    state = state.copyWith(timetableCountdownBarLengthRatio: normalized);
    await _storage.setTimetableCountdownBarLengthRatio(normalized);
  }

  Future<void> setTimetableCountdownBarRounded(bool value) async {
    state = state.copyWith(timetableCountdownBarRounded: value);
    await _storage.setTimetableCountdownBarRounded(value);
  }

  Future<void> setTimetableCountdownBarThickness(double value) async {
    final normalized = _normalizeTimetableDimension(value, 1.0, 8.0);
    state = state.copyWith(timetableCountdownBarThickness: normalized);
    await _storage.setTimetableCountdownBarThickness(normalized);
  }

  Future<void> setTimetableCountdownBarTopPadding(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.0, 8.0);
    state = state.copyWith(timetableCountdownBarTopPadding: normalized);
    await _storage.setTimetableCountdownBarTopPadding(normalized);
  }

  Future<void> setTimetableCountdownBarBottomPadding(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.0, 8.0);
    state = state.copyWith(timetableCountdownBarBottomPadding: normalized);
    await _storage.setTimetableCountdownBarBottomPadding(normalized);
  }

  Future<void> setShowCurrentTimeLine(bool value) async {
    state = state.copyWith(showCurrentTimeLine: value);
    await _storage.setShowCurrentTimeLine(value);
  }

  Future<void> setIgnoreSystemTextScale(bool value) async {
    state = state.copyWith(ignoreSystemTextScale: value);
    await _storage.setIgnoreSystemTextScale(value);
  }

  Future<void> setTimetableTextAlignCenterHorizontal(bool value) async {
    state = state.copyWith(timetableTextAlignCenterHorizontal: value);
    await _storage.setTimetableTextAlignCenterHorizontal(value);
  }

  Future<void> setTimetableTextAlignCenterVertical(bool value) async {
    state = state.copyWith(timetableTextAlignCenterVertical: value);
    await _storage.setTimetableTextAlignCenterVertical(value);
  }

  Future<void> setTimetableBorderType(TimetableBorderType value) async {
    state = state.copyWith(timetableBorderType: value);
    await _storage.setTimetableBorderType(value.storageValue);
  }

  Future<void> setTimetablePageTextColor(Color? value) async {
    state = state.copyWith(timetablePageTextColor: value);
    await _storage.setTimetablePageTextColor(value?.toARGB32());
  }

  Future<void> setCustomTimetablePageTextColor(Color value) async {
    state = state.copyWith(
      timetablePageTextColor: value,
      timetableLastCustomPageTextColor: value,
    );
    await _storage.setTimetablePageTextColor(value.toARGB32());
    await _storage.setTimetableLastCustomPageTextColor(value.toARGB32());
  }

  Future<void> setTimetableCourseBorderColor(Color? value) async {
    state = state.copyWith(timetableCourseBorderColor: value);
    await _storage.setTimetableCourseBorderColor(value?.toARGB32());
  }

  Future<void> setCustomTimetableCourseBorderColor(Color value) async {
    state = state.copyWith(
      timetableCourseBorderColor: value,
      timetableLastCustomCourseBorderColor: value,
    );
    await _storage.setTimetableCourseBorderColor(value.toARGB32());
    await _storage.setTimetableLastCustomCourseBorderColor(value.toARGB32());
  }

  Future<void> setCustomPageBackgroundColor(Color value) async {
    state = state.copyWith(
      customPageBackgroundColor: value,
      lastCustomPageBackgroundColor: value,
    );
    await _storage.setCustomPageBackgroundColor(value.toARGB32());
    await _storage.setLastCustomPageBackgroundColor(value.toARGB32());
  }

  Future<void> setToastOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(toastOpacity: normalized);
    await _storage.setToastOpacity(normalized);
  }

  Future<void> setTimetableGridLineColor(Color? value) async {
    state = state.copyWith(timetableGridLineColor: value);
    await _storage.setTimetableGridLineColor(value?.toARGB32());
  }

  Future<void> setCustomTimetableGridLineColor(Color value) async {
    state = state.copyWith(
      timetableGridLineColor: value,
      timetableLastCustomGridLineColor: value,
    );
    await _storage.setTimetableGridLineColor(value.toARGB32());
    await _storage.setTimetableLastCustomGridLineColor(value.toARGB32());
  }

  Future<void> setTimetableTodayLineColor(Color? value) async {
    state = state.copyWith(timetableTodayLineColor: value);
    await _storage.setTimetableTodayLineColor(value?.toARGB32());
  }

  Future<void> setCustomTimetableTodayLineColor(Color value) async {
    state = state.copyWith(
      timetableTodayLineColor: value,
      timetableLastCustomTodayLineColor: value,
    );
    await _storage.setTimetableTodayLineColor(value.toARGB32());
    await _storage.setTimetableLastCustomTodayLineColor(value.toARGB32());
  }

  Future<void> _refreshWidgetSettings() async {
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Widget instances may not exist yet; settings still persist for later.
    }
  }

  Future<void> setTimetableBackgroundPath(String? path) async {
    await _storage.setTimetableBackgroundPath(path);
    state = state.copyWith(timetableBackgroundPath: path);
  }

  Future<void> setTimetableDarkBackgroundPath(String? path) async {
    await _storage.setTimetableDarkBackgroundPath(path);
    state = state.copyWith(timetableDarkBackgroundPath: path);
  }

  Future<void> setTimetableUseLightBackgroundInDarkMode(bool value) async {
    state = state.copyWith(timetableUseLightBackgroundInDarkMode: value);
    await _storage.setTimetableUseLightBackgroundInDarkMode(value);
  }

  Future<void> setPageBackgroundColor(AppPageBackgroundColor? value) async {
    state = state.copyWith(
      pageBackgroundColor: value,
      customPageBackgroundColor: null,
    );
    await _storage.setPageBackgroundColor(value?.storageValue);
    await _storage.setCustomPageBackgroundColor(null);
  }

  Future<void> setTimetableGridOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetableGridOpacity: normalized);
    await _storage.setTimetableGridOpacity(normalized);
  }

  Future<void> setTimetablePageTextOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetablePageTextOpacity: normalized);
    await _storage.setTimetablePageTextOpacity(normalized);
  }

  Future<void> setTimetableCourseTextOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetableCourseTextOpacity: normalized);
    await _storage.setTimetableCourseTextOpacity(normalized);
  }

  Future<void> setTimetableGridLineWidth(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.5, 3.0);
    state = state.copyWith(timetableGridLineWidth: normalized);
    await _storage.setTimetableGridLineWidth(normalized);
  }

  Future<void> setTimetableTodayLineWidth(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.5, 4.0);
    state = state.copyWith(timetableTodayLineWidth: normalized);
    await _storage.setTimetableTodayLineWidth(normalized);
  }

  Future<void> setTimetableTodayLineOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetableTodayLineOpacity: normalized);
    await _storage.setTimetableTodayLineOpacity(normalized);
  }

  Future<void> setShowTodayHorizontalGridLines(bool value) async {
    state = state.copyWith(showTodayHorizontalGridLines: value);
    await _storage.setShowTodayHorizontalGridLines(value);
  }

  Future<void> setTimetableCourseTextSize(double value) async {
    final normalized = _normalizeTimetableDimension(value, 8.0, 18.0);
    await _storage.setTimetableCourseTextSize(normalized);
    state = state.copyWith(timetableCourseTextSize: normalized);
  }

  Future<void> setTimetableTimeTextSize(double value) async {
    final normalized = _normalizeTimetableDimension(value, 8.0, 18.0);
    await _storage.setTimetableTimeTextSize(normalized);
    state = state.copyWith(timetableTimeTextSize: normalized);
  }

  Future<void> setTimetableDateTextSize(double value) async {
    final normalized = _normalizeTimetableDimension(value, 8.0, 18.0);
    await _storage.setTimetableDateTextSize(normalized);
    state = state.copyWith(timetableDateTextSize: normalized);
  }

  Future<void> setTimetableDayTextMarkerSize(double value) async {
    final normalized = _normalizeTimetableDimension(value, 4.0, 16.0);
    await _storage.setTimetableDayTextMarkerSize(normalized);
    state = state.copyWith(timetableDayTextMarkerSize: normalized);
  }

  Future<void> setTimetableCourseBorderWidth(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.5, 3.0);
    state = state.copyWith(timetableCourseBorderWidth: normalized);
    await _storage.setTimetableCourseBorderWidth(normalized);
  }

  Future<void> setTimetableCourseBorderOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetableCourseBorderOpacity: normalized);
    await _storage.setTimetableCourseBorderOpacity(normalized);
  }

  Future<void> resetTimetableAppearance() async {
    Color? activeCustomColor(Color? color, Color? lastCustomColor) =>
        color != null && color == lastCustomColor ? color : null;

    await _storage.resetTimetableAppearance();
    const defaults = AppSettings();
    state = state.copyWith(
      // 保留用户选择的主题模式，仅重置其他个性化项。
      themeColor: defaults.themeColor,
      customThemeColor: null,
      timetableBackgroundPath: null,
      timetableDarkBackgroundPath: null,
      timetableUseLightBackgroundInDarkMode:
          defaults.timetableUseLightBackgroundInDarkMode,
      pageBackgroundColor: null,
      toastOpacity: defaults.toastOpacity,
      timetableGridOpacity: defaults.timetableGridOpacity,
      timetablePageTextOpacity: defaults.timetablePageTextOpacity,
      timetableGridLineColor: activeCustomColor(
        state.timetableGridLineColor,
        state.timetableLastCustomGridLineColor,
      ),
      timetableGridLineWidth: defaults.timetableGridLineWidth,
      timetableCourseTextSize: defaults.timetableCourseTextSize,
      timetableCourseTextOpacity: defaults.timetableCourseTextOpacity,
      timetableTimeTextSize: defaults.timetableTimeTextSize,
      timetableDateTextSize: defaults.timetableDateTextSize,
      timetableCourseBorderWidth: defaults.timetableCourseBorderWidth,
      timetableCourseBorderOpacity: defaults.timetableCourseBorderOpacity,
      showTimetableGridLines: defaults.showTimetableGridLines,
      showTodayGridLines: defaults.showTodayGridLines,
      timetableTodayLineColor: activeCustomColor(
        state.timetableTodayLineColor,
        state.timetableLastCustomTodayLineColor,
      ),
      timetableTodayLineWidth: defaults.timetableTodayLineWidth,
      timetableTodayLineOpacity: defaults.timetableTodayLineOpacity,
      showTodayHorizontalGridLines: defaults.showTodayHorizontalGridLines,
      widgetThemePreference: defaults.widgetThemePreference,
      widgetFontScale: defaults.widgetFontScale,
      widgetBackgroundAlpha: defaults.widgetBackgroundAlpha,
      widgetTextOpacity: defaults.widgetTextOpacity,
      widgetBackgroundColor: activeCustomColor(
        state.widgetBackgroundColor,
        state.lastCustomWidgetBackgroundColor,
      ),
      widgetBackgroundPath: null,
      widgetDarkBackgroundPath: null,
      widgetUseLightBackgroundInDarkMode:
          defaults.widgetUseLightBackgroundInDarkMode,
      widgetTextColor: activeCustomColor(
        state.widgetTextColor,
        state.lastCustomWidgetTextColor,
      ),
      widgetHideTeacher: defaults.widgetHideTeacher,
      widgetHideLocation: defaults.widgetHideLocation,
      widgetHideDate: defaults.widgetHideDate,
      // 重置后课节高度回到自适应默认值（可用高度 / 11）。
      timetableSectionHeight: estimateAdaptiveSectionHeight(),
      timetableSectionHeightIsCustom: false,
      timetableTimeColumnWidth: defaults.timetableTimeColumnWidth,
      timetableDayHeaderHeight: defaults.timetableDayHeaderHeight,
      timetableCourseCornerRadius: defaults.timetableCourseCornerRadius,
      timetableCourseInnerPadding: defaults.timetableCourseInnerPadding,
      timetableCourseOuterPadding: defaults.timetableCourseOuterPadding,
      timetableCourseAlpha: defaults.timetableCourseAlpha,
      timetableCourseTextTemplate: defaults.timetableCourseTextTemplate,
      timetableDashedBorderDensity: defaults.timetableDashedBorderDensity,
      timetableHideSectionTime: defaults.timetableHideSectionTime,
      timetableHideDateUnderDay: defaults.timetableHideDateUnderDay,
      timetableDayColorMarkers: defaults.timetableDayColorMarkers,
      timetableDayTextMarkers: defaults.timetableDayTextMarkers,
      timetableDayTextMarkerSize: defaults.timetableDayTextMarkerSize,
      timetableDayTextMarkerPosition: defaults.timetableDayTextMarkerPosition,
      timetableDayTextMarkerPadding: defaults.timetableDayTextMarkerPadding,
      timetableCountdownBarLengthRatio:
          defaults.timetableCountdownBarLengthRatio,
      timetableCountdownBarRounded: defaults.timetableCountdownBarRounded,
      timetableCountdownBarThickness: defaults.timetableCountdownBarThickness,
      timetableCountdownBarTopPadding: defaults.timetableCountdownBarTopPadding,
      timetableCountdownBarBottomPadding:
          defaults.timetableCountdownBarBottomPadding,
      showCurrentTimeLine: defaults.showCurrentTimeLine,
      ignoreSystemTextScale: defaults.ignoreSystemTextScale,
      timetableTextAlignCenterHorizontal:
          defaults.timetableTextAlignCenterHorizontal,
      timetableTextAlignCenterVertical:
          defaults.timetableTextAlignCenterVertical,
      timetableBorderType: defaults.timetableBorderType,
      timetablePageTextColor: activeCustomColor(
        state.timetablePageTextColor,
        state.timetableLastCustomPageTextColor,
      ),
      timetableCourseBorderColor: activeCustomColor(
        state.timetableCourseBorderColor,
        state.timetableLastCustomCourseBorderColor,
      ),
    );
    await _refreshWidgetSettings();
  }

  Future<void> setShowTimetableGridLines(bool value) async {
    state = state.copyWith(showTimetableGridLines: value);
    await _storage.setShowTimetableGridLines(value);
  }

  Future<void> setShowTodayGridLines(bool value) async {
    state = state.copyWith(showTodayGridLines: value);
    await _storage.setShowTodayGridLines(value);
  }

  Future<void> setTimetableDayColorMarkers(bool value) async {
    state = state.copyWith(timetableDayColorMarkers: value);
    await _storage.setTimetableDayColorMarkers(value);
  }

  Future<void> setTimetableDayTextMarkers(bool value) async {
    state = state.copyWith(timetableDayTextMarkers: value);
    await _storage.setTimetableDayTextMarkers(value);
  }

  Future<void> setUseCloudTimetableAdjustments(bool value) async {
    await _storage.setUseCloudTimetableAdjustments(value);
    state = state.copyWith(useCloudTimetableAdjustments: value);
  }

  Future<void> setServiceFeatureVisible(
    AppServiceFeature feature,
    bool visible,
  ) async {
    final hidden = {...state.hiddenServiceFeatures};
    if (visible) {
      hidden.remove(feature);
    } else {
      hidden.add(feature);
    }
    await _storage.setHiddenServiceFeatures(
      hidden.map((item) => item.storageValue),
    );
    state = state.copyWith(hiddenServiceFeatures: hidden);
  }
}

double _normalizeTimetableDimension(double value, double min, double max) {
  final rounded = (value * 10).round() / 10.0;
  return rounded.clamp(min, max).toDouble();
}
