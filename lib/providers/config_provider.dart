import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_config.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final configProvider =
    NotifierProvider<ConfigNotifier, UserConfig>(ConfigNotifier.new);

class ConfigNotifier extends Notifier<UserConfig> {
  late StorageService _storage;

  @override
  UserConfig build() {
    _storage = ref.watch(storageServiceProvider);
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
    await _storage.clearCredentials();
    state = const UserConfig();
  }
}
