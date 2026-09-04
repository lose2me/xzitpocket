import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_config.dart';
import '../services/course_storage.dart';
import '../services/credential_storage.dart';
import '../services/control_service.dart';
import '../services/preferences_storage.dart';
import '../services/tools_data_manager.dart';

final courseStorageProvider = Provider<CourseStorage>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final preferencesStorageProvider = Provider<PreferencesStorage>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final savedRoomIdProvider = NotifierProvider<SavedRoomIdNotifier, String?>(
  SavedRoomIdNotifier.new,
);

class SavedRoomIdNotifier extends Notifier<String?> {
  @override
  String? build() {
    return ref.watch(preferencesStorageProvider).getSavedPowerRoomId();
  }

  void set(String? value) => state = value;
}

final configProvider = NotifierProvider<ConfigNotifier, UserConfig>(
  ConfigNotifier.new,
);

class ConfigNotifier extends Notifier<UserConfig> {
  late PreferencesStorage _storage;

  @override
  UserConfig build() {
    _storage = ref.watch(preferencesStorageProvider);
    return UserConfig(
      studentId: _storage.getStudentId(),
      studentName: _storage.getStudentName(),
    );
  }

  Future<void> updateFromLogin({
    required String studentId,
    required String studentName,
  }) async {
    final previousStudentId = _storage.getStudentId();
    if (previousStudentId != null && previousStudentId != studentId) {
      ToolsDataManager.instance.clear();
      await Future.wait([
        _storage.clearUserToolCaches(),
        _storage.clearPowerCache(),
      ]);
    }
    await Future.wait([
      _storage.setStudentId(studentId),
      _storage.setStudentName(studentName),
    ]);
    state = state.copyWith(studentId: studentId, studentName: studentName);
  }

  Future<void> logout() async {
    unawaited(ControlService.instance.logout());
    ToolsDataManager.instance.clear();
    await Future.wait([
      _storage.clearStudentInfo(),
      _storage.clearUserToolCaches(),
      _storage.clearPowerCache(),
      CredentialStorage.clearPassword(),
    ]);
    state = const UserConfig();
  }
}
