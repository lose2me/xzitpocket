import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_config.dart';
import '../services/course_storage.dart';
import '../services/credential_storage.dart';
import '../services/control_service.dart';
import '../services/preferences_storage.dart';
import '../services/resource_center_cache.dart';
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
      collegeName: _storage.getCollegeName(),
      className: _storage.getClassName(),
      majorName: _storage.getMajorName(),
    );
  }

  Future<void> updateFromLogin({
    required String studentId,
    required String studentName,
    required String collegeName,
    required String className,
    String majorName = '',
  }) async {
    final previousStudentId = _storage.getStudentId();
    if (previousStudentId != null && previousStudentId != studentId) {
      ToolsDataManager.instance.clear();
      await Future.wait([
        _storage.clearUserToolCaches(),
        _storage.clearPowerCache(),
        ResourceCoverCache.instance.clear(),
      ]);
    }
    await Future.wait([
      if (state.studentId != studentId) _storage.setStudentId(studentId),
      if (state.studentName != studentName)
        _storage.setStudentName(studentName),
      if (state.collegeName != collegeName)
        _storage.setCollegeName(collegeName),
      if (state.className != className) _storage.setClassName(className),
      if (majorName.isNotEmpty && state.majorName != majorName)
        _storage.setMajorName(majorName),
    ]);
    // Login succeeded: open the control communication gate before any
    // post-login sync (profile update, question banks, telemetry) runs.
    ControlService.instance.updateLoginGate(studentId);
    if (state.studentId != studentId ||
        state.studentName != studentName ||
        state.collegeName != collegeName ||
        state.className != className ||
        (majorName.isNotEmpty && state.majorName != majorName)) {
      state = state.copyWith(
        studentId: studentId,
        studentName: studentName,
        collegeName: collegeName,
        className: className,
        majorName: majorName.isNotEmpty ? majorName : null,
      );
    }
  }

  Future<void> logout() async {
    unawaited(ControlService.instance.logout());
    ControlService.instance.updateLoginGate(null);
    ToolsDataManager.instance.clear();
    await Future.wait([
      _storage.clearStudentInfo(),
      _storage.clearSavedPowerRoomId(),
      _storage.clearUserToolCaches(),
      _storage.clearPowerCache(),
      ResourceCoverCache.instance.clear(),
      CredentialStorage.clearPassword(),
    ]);
    ref.read(savedRoomIdProvider.notifier).set(null);
    state = const UserConfig();
  }
}
