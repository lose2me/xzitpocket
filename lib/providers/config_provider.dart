import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_config.dart';
import '../services/course_storage.dart';
import '../services/credential_storage.dart';
import '../services/preferences_storage.dart';

final courseStorageProvider = Provider<CourseStorage>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final preferencesStorageProvider = Provider<PreferencesStorage>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final configProvider =
    NotifierProvider<ConfigNotifier, UserConfig>(ConfigNotifier.new);

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
    await Future.wait([
      _storage.setStudentId(studentId),
      _storage.setStudentName(studentName),
    ]);
    state = state.copyWith(studentId: studentId, studentName: studentName);
  }

  Future<void> logout() async {
    await _storage.clearStudentInfo();
    await CredentialStorage.clearPassword();
    state = const UserConfig();
  }
}
