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
      timetableBackgroundOpacity: _storage.getTimetableBackgroundOpacity(),
      timetableComponentOpacity: _storage.getTimetableComponentOpacity(),
      showTimetableGridLines: _storage.getShowTimetableGridLines(),
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

  Future<void> setShowTimetableGridLines(bool value) async {
    await _storage.setShowTimetableGridLines(value);
    state = state.copyWith(showTimetableGridLines: value);
  }
}
