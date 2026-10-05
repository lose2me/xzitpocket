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
    final customThemeColor = _storage.getCustomThemeColor();
    final customPageBackgroundColor = _storage.getCustomPageBackgroundColor();
    final courseTextColor = _storage.getTimetableCourseTextColor();
    final pageTextColor = _storage.getTimetablePageTextColor();
    if (_storage.getLastCustomThemeColor() == null &&
        customThemeColor != null) {
      unawaited(_storage.setLastCustomThemeColor(customThemeColor));
    }
    if (_storage.getTimetableLastCustomCourseTextColor() == null &&
        courseTextColor != null) {
      unawaited(
        _storage.setTimetableLastCustomCourseTextColor(courseTextColor),
      );
    }
    if (_storage.getTimetableLastCustomPageTextColor() == null &&
        pageTextColor != null) {
      unawaited(_storage.setTimetableLastCustomPageTextColor(pageTextColor));
    }
    unawaited(_storage.clearLegacyTimetableBackgroundSettings());
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
      timetableSectionHeight: _storage.getTimetableSectionHeight(),
      timetableTimeColumnWidth: _storage.getTimetableTimeColumnWidth(),
      timetableDayHeaderHeight: _storage.getTimetableDayHeaderHeight(),
      timetableCourseCornerRadius: _storage.getTimetableCourseCornerRadius(),
      timetableCourseInnerPadding: _storage.getTimetableCourseInnerPadding(),
      timetableCourseOuterPadding: _storage.getTimetableCourseOuterPadding(),
      timetableCourseAlpha: _storage.getTimetableCourseAlpha(),
      timetableCourseFontScale: _storage.getTimetableCourseFontScale(),
      timetableAddBlankLineAfterTitle: _storage
          .getTimetableAddBlankLineAfterTitle(),
      timetableDashedBorderDensity: _storage.getTimetableDashedBorderDensity(),
      timetableHideSectionTime: _storage.getTimetableHideSectionTime(),
      timetableHideDateUnderDay: _storage.getTimetableHideDateUnderDay(),
      timetableShowStartTime: _storage.getTimetableShowStartTime(),
      timetableHideLocation: _storage.getTimetableHideLocation(),
      timetableHideTeacher: _storage.getTimetableHideTeacher(),
      timetableHideTeacherBrackets: _storage.getTimetableHideTeacherBrackets(),
      timetableRemoveLocationAt: _storage.getTimetableRemoveLocationAt(),
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
      timetableCourseTextColor: courseTextColor == null
          ? null
          : Color(courseTextColor),
      timetableLastCustomCourseTextColor:
          (_storage.getTimetableLastCustomCourseTextColor() ??
                  courseTextColor) ==
              null
          ? null
          : Color(
              _storage.getTimetableLastCustomCourseTextColor() ??
                  courseTextColor!,
            ),
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
      timetableComponentOpacity: _storage.getTimetableComponentOpacity(),
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
    state = state.copyWith(timetableSectionHeight: normalized);
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

  Future<void> setTimetableCourseFontScale(double value) async {
    final normalized = value.clamp(0.5, 2.0).toDouble();
    state = state.copyWith(timetableCourseFontScale: normalized);
    await _storage.setTimetableCourseFontScale(normalized);
  }

  Future<void> setTimetableAddBlankLineAfterTitle(bool value) async {
    state = state.copyWith(timetableAddBlankLineAfterTitle: value);
    await _storage.setTimetableAddBlankLineAfterTitle(value);
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

  Future<void> setTimetableShowStartTime(bool value) async {
    state = state.copyWith(timetableShowStartTime: value);
    await _storage.setTimetableShowStartTime(value);
  }

  Future<void> setTimetableHideLocation(bool value) async {
    state = state.copyWith(timetableHideLocation: value);
    await _storage.setTimetableHideLocation(value);
  }

  Future<void> setTimetableHideTeacher(bool value) async {
    state = state.copyWith(timetableHideTeacher: value);
    await _storage.setTimetableHideTeacher(value);
  }

  Future<void> setTimetableHideTeacherBrackets(bool value) async {
    state = state.copyWith(timetableHideTeacherBrackets: value);
    await _storage.setTimetableHideTeacherBrackets(value);
  }

  Future<void> setTimetableRemoveLocationAt(bool value) async {
    state = state.copyWith(timetableRemoveLocationAt: value);
    await _storage.setTimetableRemoveLocationAt(value);
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

  Future<void> setTimetableCourseTextColor(Color? value) async {
    state = state.copyWith(timetableCourseTextColor: value);
    await _storage.setTimetableCourseTextColor(value?.toARGB32());
  }

  Future<void> setCustomTimetableCourseTextColor(Color value) async {
    state = state.copyWith(
      timetableCourseTextColor: value,
      timetableLastCustomCourseTextColor: value,
    );
    await _storage.setTimetableCourseTextColor(value.toARGB32());
    await _storage.setTimetableLastCustomCourseTextColor(value.toARGB32());
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

  Future<void> setTimetableComponentOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(timetableComponentOpacity: normalized);
    await _storage.setTimetableComponentOpacity(normalized);
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
      themePreference: defaults.themePreference,
      themeColor: defaults.themeColor,
      customThemeColor: null,
      timetableBackgroundPath: null,
      timetableDarkBackgroundPath: null,
      timetableUseLightBackgroundInDarkMode:
          defaults.timetableUseLightBackgroundInDarkMode,
      pageBackgroundColor: null,
      toastOpacity: defaults.toastOpacity,
      timetableComponentOpacity: defaults.timetableComponentOpacity,
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
      timetableSectionHeight: defaults.timetableSectionHeight,
      timetableTimeColumnWidth: defaults.timetableTimeColumnWidth,
      timetableDayHeaderHeight: defaults.timetableDayHeaderHeight,
      timetableCourseCornerRadius: defaults.timetableCourseCornerRadius,
      timetableCourseInnerPadding: defaults.timetableCourseInnerPadding,
      timetableCourseOuterPadding: defaults.timetableCourseOuterPadding,
      timetableCourseAlpha: defaults.timetableCourseAlpha,
      timetableCourseFontScale: defaults.timetableCourseFontScale,
      timetableAddBlankLineAfterTitle: defaults.timetableAddBlankLineAfterTitle,
      timetableDashedBorderDensity: defaults.timetableDashedBorderDensity,
      timetableHideSectionTime: defaults.timetableHideSectionTime,
      timetableHideDateUnderDay: defaults.timetableHideDateUnderDay,
      timetableShowStartTime: defaults.timetableShowStartTime,
      timetableHideLocation: defaults.timetableHideLocation,
      timetableHideTeacher: defaults.timetableHideTeacher,
      timetableHideTeacherBrackets: defaults.timetableHideTeacherBrackets,
      timetableRemoveLocationAt: defaults.timetableRemoveLocationAt,
      timetableTextAlignCenterHorizontal:
          defaults.timetableTextAlignCenterHorizontal,
      timetableTextAlignCenterVertical:
          defaults.timetableTextAlignCenterVertical,
      timetableBorderType: defaults.timetableBorderType,
      timetablePageTextColor: activeCustomColor(
        state.timetablePageTextColor,
        state.timetableLastCustomPageTextColor,
      ),
      timetableCourseTextColor: activeCustomColor(
        state.timetableCourseTextColor,
        state.timetableLastCustomCourseTextColor,
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
