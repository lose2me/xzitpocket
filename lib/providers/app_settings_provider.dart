import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
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
    unawaited(_storage.clearLegacyTimetableBackgroundSettings());
    unawaited(NativeAutomationService.refreshClassAutomation());
    unawaited(NativeAutomationService.refreshCourseReminders());
    return AppSettings(
      themePreference: AppThemePreference.fromStorage(
        _storage.getThemePreference(),
      ),
      themeColor: AppThemeColor.fromStorage(_storage.getThemeColor()),
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
      widgetHideTeacher: _storage.getWidgetHideTeacher(),
      widgetHideLocation: _storage.getWidgetHideLocation(),
      widgetHideDate: _storage.getWidgetHideDate(),
      timetableSectionHeight: _storage.getTimetableSectionHeight(),
      timetableTimeColumnWidth: _storage.getTimetableTimeColumnWidth(),
      timetableDayHeaderHeight: _storage.getTimetableDayHeaderHeight(),
      timetableCourseCornerRadius: _storage.getTimetableCourseCornerRadius(),
      timetableCourseInnerPadding: _storage.getTimetableCourseInnerPadding(),
      timetableCourseOuterPadding: _storage.getTimetableCourseOuterPadding(),
      timetableCourseAlpha: _storage.getTimetableCourseAlpha(),
      timetableCourseFontScale: _storage.getTimetableCourseFontScale(),
      timetableHideSectionTime: _storage.getTimetableHideSectionTime(),
      timetableHideDateUnderDay: _storage.getTimetableHideDateUnderDay(),
      timetableShowStartTime: _storage.getTimetableShowStartTime(),
      timetableHideLocation: _storage.getTimetableHideLocation(),
      timetableHideTeacher: _storage.getTimetableHideTeacher(),
      timetableRemoveLocationAt: _storage.getTimetableRemoveLocationAt(),
      timetableTextAlignCenterHorizontal: _storage
          .getTimetableTextAlignCenterHorizontal(),
      timetableTextAlignCenterVertical: _storage
          .getTimetableTextAlignCenterVertical(),
      timetableBorderType: TimetableBorderType.fromStorage(
        _storage.getTimetableBorderType(),
      ),
      timetablePageTextColor: _storage.getTimetablePageTextColor() == null
          ? null
          : Color(_storage.getTimetablePageTextColor()!),
      timetableCourseTextColor: _storage.getTimetableCourseTextColor() == null
          ? null
          : Color(_storage.getTimetableCourseTextColor()!),
      timetableBackgroundPath: _storage.getTimetableBackgroundPath(),
      timetableComponentOpacity: _storage.getTimetableComponentOpacity(),
      timetableGridOpacity: _storage.getTimetableGridOpacity(),
      timetableCourseTextSize: _storage.getTimetableCourseTextSize(),
      timetableTimeTextSize: _storage.getTimetableTimeTextSize(),
      timetableDateTextSize: _storage.getTimetableDateTextSize(),
      timetableCourseBorderWidth: _storage.getTimetableCourseBorderWidth(),
      timetableCourseBorderOpacity: _storage.getTimetableCourseBorderOpacity(),
      showTimetableGridLines: _storage.getShowTimetableGridLines(),
      showTodayGridLines: _storage.getShowTodayGridLines(),
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
    await _storage.setThemePreference(preference.storageValue);
    state = state.copyWith(themePreference: preference);
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Ignore widget refresh failures so theme changes still apply in-app.
    }
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    await _storage.setThemeColor(color.storageValue);
    state = state.copyWith(themeColor: color);
    try {
      await WidgetService.refreshWidget();
    } on WidgetSyncException {
      // Ignore widget refresh failures so theme changes still apply in-app.
    }
  }

  Future<void> setClassAutomationMode(ClassAutomationMode mode) async {
    await _storage.setClassAutomationMode(mode.storageValue);
    state = state.copyWith(classAutomationMode: mode);
    await NativeAutomationService.refreshClassAutomation();
  }

  Future<void> setCourseReminderEnabled(bool value) async {
    await _storage.setCourseReminderEnabled(value);
    state = state.copyWith(courseReminderEnabled: value);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setCourseReminderMinutes(int value) async {
    final normalized = value.clamp(1, 60);
    await _storage.setCourseReminderMinutes(normalized);
    state = state.copyWith(courseReminderMinutes: normalized);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setWearableNotificationCompatibility(bool value) async {
    await _storage.setWearableNotificationCompatibility(value);
    state = state.copyWith(wearableNotificationCompatibility: value);
    await NativeAutomationService.refreshCourseReminders();
  }

  Future<void> setWidgetThemePreference(WidgetThemePreference value) async {
    await _storage.setWidgetThemePreference(value.storageValue);
    state = state.copyWith(widgetThemePreference: value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetFontScale(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    await _storage.setWidgetFontScale(normalized);
    state = state.copyWith(widgetFontScale: normalized);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetBackgroundAlpha(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    await _storage.setWidgetBackgroundAlpha(normalized);
    state = state.copyWith(widgetBackgroundAlpha: normalized);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideTeacher(bool value) async {
    await _storage.setWidgetHideTeacher(value);
    state = state.copyWith(widgetHideTeacher: value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideLocation(bool value) async {
    await _storage.setWidgetHideLocation(value);
    state = state.copyWith(widgetHideLocation: value);
    await _refreshWidgetSettings();
  }

  Future<void> setWidgetHideDate(bool value) async {
    await _storage.setWidgetHideDate(value);
    state = state.copyWith(widgetHideDate: value);
    await _refreshWidgetSettings();
  }

  Future<void> setTimetableSectionHeight(double value) async {
    final normalized = value.clamp(40.0, 140.0).toDouble();
    await _storage.setTimetableSectionHeight(normalized);
    state = state.copyWith(timetableSectionHeight: normalized);
  }

  Future<void> setTimetableTimeColumnWidth(double value) async {
    final normalized = value.clamp(20.0, 80.0).toDouble();
    await _storage.setTimetableTimeColumnWidth(normalized);
    state = state.copyWith(timetableTimeColumnWidth: normalized);
  }

  Future<void> setTimetableDayHeaderHeight(double value) async {
    final normalized = value.clamp(30.0, 80.0).toDouble();
    await _storage.setTimetableDayHeaderHeight(normalized);
    state = state.copyWith(timetableDayHeaderHeight: normalized);
  }

  Future<void> setTimetableCourseCornerRadius(double value) async {
    final normalized = value.clamp(0.0, 24.0).toDouble();
    await _storage.setTimetableCourseCornerRadius(normalized);
    state = state.copyWith(timetableCourseCornerRadius: normalized);
  }

  Future<void> setTimetableCourseInnerPadding(double value) async {
    final normalized = value.clamp(0.0, 12.0).toDouble();
    await _storage.setTimetableCourseInnerPadding(normalized);
    state = state.copyWith(timetableCourseInnerPadding: normalized);
  }

  Future<void> setTimetableCourseOuterPadding(double value) async {
    final normalized = value.clamp(0.0, 8.0).toDouble();
    await _storage.setTimetableCourseOuterPadding(normalized);
    state = state.copyWith(timetableCourseOuterPadding: normalized);
  }

  Future<void> setTimetableCourseAlpha(double value) async {
    final normalized = value.clamp(0.1, 1.0).toDouble();
    await _storage.setTimetableCourseAlpha(normalized);
    state = state.copyWith(timetableCourseAlpha: normalized);
  }

  Future<void> setTimetableCourseFontScale(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    await _storage.setTimetableCourseFontScale(normalized);
    state = state.copyWith(timetableCourseFontScale: normalized);
  }

  Future<void> setTimetableHideSectionTime(bool value) async {
    await _storage.setTimetableHideSectionTime(value);
    state = state.copyWith(timetableHideSectionTime: value);
  }

  Future<void> setTimetableHideDateUnderDay(bool value) async {
    await _storage.setTimetableHideDateUnderDay(value);
    state = state.copyWith(timetableHideDateUnderDay: value);
  }

  Future<void> setTimetableShowStartTime(bool value) async {
    await _storage.setTimetableShowStartTime(value);
    state = state.copyWith(timetableShowStartTime: value);
  }

  Future<void> setTimetableHideLocation(bool value) async {
    await _storage.setTimetableHideLocation(value);
    state = state.copyWith(timetableHideLocation: value);
  }

  Future<void> setTimetableHideTeacher(bool value) async {
    await _storage.setTimetableHideTeacher(value);
    state = state.copyWith(timetableHideTeacher: value);
  }

  Future<void> setTimetableRemoveLocationAt(bool value) async {
    await _storage.setTimetableRemoveLocationAt(value);
    state = state.copyWith(timetableRemoveLocationAt: value);
  }

  Future<void> setTimetableTextAlignCenterHorizontal(bool value) async {
    await _storage.setTimetableTextAlignCenterHorizontal(value);
    state = state.copyWith(timetableTextAlignCenterHorizontal: value);
  }

  Future<void> setTimetableTextAlignCenterVertical(bool value) async {
    await _storage.setTimetableTextAlignCenterVertical(value);
    state = state.copyWith(timetableTextAlignCenterVertical: value);
  }

  Future<void> setTimetableBorderType(TimetableBorderType value) async {
    await _storage.setTimetableBorderType(value.storageValue);
    state = state.copyWith(timetableBorderType: value);
  }

  Future<void> setTimetablePageTextColor(Color? value) async {
    await _storage.setTimetablePageTextColor(value?.toARGB32());
    state = state.copyWith(timetablePageTextColor: value);
  }

  Future<void> setTimetableCourseTextColor(Color? value) async {
    await _storage.setTimetableCourseTextColor(value?.toARGB32());
    state = state.copyWith(timetableCourseTextColor: value);
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

  Future<void> setTimetableComponentOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    await _storage.setTimetableComponentOpacity(normalized);
    state = state.copyWith(timetableComponentOpacity: normalized);
  }

  Future<void> setTimetableGridOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    await _storage.setTimetableGridOpacity(normalized);
    state = state.copyWith(timetableGridOpacity: normalized);
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

  Future<void> setTimetableCourseBorderWidth(double value) async {
    final normalized = _normalizeTimetableDimension(value, 0.0, 3.0);
    await _storage.setTimetableCourseBorderWidth(normalized);
    state = state.copyWith(timetableCourseBorderWidth: normalized);
  }

  Future<void> setTimetableCourseBorderOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    await _storage.setTimetableCourseBorderOpacity(normalized);
    state = state.copyWith(timetableCourseBorderOpacity: normalized);
  }

  Future<void> resetTimetableAppearance() async {
    await _storage.resetTimetableAppearance();
    const defaults = AppSettings();
    state = state.copyWith(
      timetableBackgroundPath: null,
      timetableComponentOpacity: defaults.timetableComponentOpacity,
      timetableGridOpacity: defaults.timetableGridOpacity,
      timetableCourseTextSize: defaults.timetableCourseTextSize,
      timetableTimeTextSize: defaults.timetableTimeTextSize,
      timetableDateTextSize: defaults.timetableDateTextSize,
      timetableCourseBorderWidth: defaults.timetableCourseBorderWidth,
      timetableCourseBorderOpacity: defaults.timetableCourseBorderOpacity,
      showTimetableGridLines: defaults.showTimetableGridLines,
      showTodayGridLines: defaults.showTodayGridLines,
      widgetThemePreference: defaults.widgetThemePreference,
      widgetFontScale: defaults.widgetFontScale,
      widgetBackgroundAlpha: defaults.widgetBackgroundAlpha,
      widgetHideTeacher: defaults.widgetHideTeacher,
      widgetHideLocation: defaults.widgetHideLocation,
      widgetHideDate: defaults.widgetHideDate,
      timetableSectionHeight: defaults.timetableSectionHeight,
      timetableTimeColumnWidth: defaults.timetableTimeColumnWidth,
      timetableDayHeaderHeight: defaults.timetableDayHeaderHeight,
      timetableCourseCornerRadius: defaults.timetableCourseCornerRadius,
      timetableCourseInnerPadding: defaults.timetableCourseInnerPadding,
      timetableCourseOuterPadding: defaults.timetableCourseOuterPadding,
      timetableCourseAlpha: defaults.timetableCourseAlpha,
      timetableCourseFontScale: defaults.timetableCourseFontScale,
      timetableHideSectionTime: defaults.timetableHideSectionTime,
      timetableHideDateUnderDay: defaults.timetableHideDateUnderDay,
      timetableShowStartTime: defaults.timetableShowStartTime,
      timetableHideLocation: defaults.timetableHideLocation,
      timetableHideTeacher: defaults.timetableHideTeacher,
      timetableRemoveLocationAt: defaults.timetableRemoveLocationAt,
      timetableTextAlignCenterHorizontal:
          defaults.timetableTextAlignCenterHorizontal,
      timetableTextAlignCenterVertical:
          defaults.timetableTextAlignCenterVertical,
      timetableBorderType: defaults.timetableBorderType,
      timetablePageTextColor: null,
      timetableCourseTextColor: null,
    );
    await _refreshWidgetSettings();
  }

  Future<void> setShowTimetableGridLines(bool value) async {
    await _storage.setShowTimetableGridLines(value);
    state = state.copyWith(showTimetableGridLines: value);
  }

  Future<void> setShowTodayGridLines(bool value) async {
    await _storage.setShowTodayGridLines(value);
    state = state.copyWith(showTodayGridLines: value);
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
