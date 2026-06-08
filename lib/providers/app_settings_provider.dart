import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_settings.dart';
import '../services/native_automation_service.dart';
import '../services/storage_service.dart';
import '../services/widget_service.dart';
import 'config_provider.dart';

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  late StorageService _storage;

  @override
  AppSettings build() {
    _storage = ref.watch(storageServiceProvider);
    unawaited(NativeAutomationService.refreshClassAutomation());
    return AppSettings(
      themePreference: AppThemePreference.fromStorage(
        _storage.getThemePreference(),
      ),
      classAutomationMode: ClassAutomationMode.fromStorage(
        _storage.getClassAutomationMode(),
      ),
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

  Future<void> setClassAutomationMode(ClassAutomationMode mode) async {
    await _storage.setClassAutomationMode(mode.storageValue);
    state = state.copyWith(classAutomationMode: mode);
    await NativeAutomationService.refreshClassAutomation();
  }
}
