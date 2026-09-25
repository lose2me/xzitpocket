import 'dart:async';

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
    unawaited(NativeAutomationService.refreshClassAutomation());
    return AppSettings(
      themePreference: AppThemePreference.fromStorage(
        _storage.getThemePreference(),
      ),
      themeColor: AppThemeColor.fromStorage(_storage.getThemeColor()),
      classAutomationMode: ClassAutomationMode.fromStorage(
        _storage.getClassAutomationMode(),
      ),
      timetableBackgroundPath: _storage.getTimetableBackgroundPath(),
      timetableBackgroundFullscreen: _storage
          .getTimetableBackgroundFullscreen(),
      timetableBackgroundOpacity: _storage.getTimetableBackgroundOpacity(),
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

  Future<void> setTimetableBackgroundPath(String? path) async {
    await _storage.setTimetableBackgroundPath(path);
    state = state.copyWith(timetableBackgroundPath: path);
  }

  Future<void> setTimetableBackgroundFullscreen(bool value) async {
    await _storage.setTimetableBackgroundFullscreen(value);
    state = state.copyWith(timetableBackgroundFullscreen: value);
  }

  Future<void> setTimetableBackgroundOpacity(double value) async {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    await _storage.setTimetableBackgroundOpacity(normalized);
    state = state.copyWith(timetableBackgroundOpacity: normalized);
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
      timetableBackgroundFullscreen: defaults.timetableBackgroundFullscreen,
      timetableBackgroundOpacity: defaults.timetableBackgroundOpacity,
      timetableComponentOpacity: defaults.timetableComponentOpacity,
      timetableGridOpacity: defaults.timetableGridOpacity,
      timetableCourseTextSize: defaults.timetableCourseTextSize,
      timetableTimeTextSize: defaults.timetableTimeTextSize,
      timetableDateTextSize: defaults.timetableDateTextSize,
      timetableCourseBorderWidth: defaults.timetableCourseBorderWidth,
      timetableCourseBorderOpacity: defaults.timetableCourseBorderOpacity,
      showTimetableGridLines: defaults.showTimetableGridLines,
      showTodayGridLines: defaults.showTodayGridLines,
    );
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
