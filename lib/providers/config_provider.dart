import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_config.dart';
import '../services/storage_service.dart';

/// 学期起始日期（固定值）
final semesterStartDate = DateTime(2026, 3, 2);

/// 学期总周数
const semesterTotalWeeks = 25;

/// 教务系统地址（按优先级排列）
const baseUrls = [
  'https://jwglxt.xzit.edu.cn/jwglxt',
  'http://jwglxt.xzit.edu.cn/jwglxt',
];

/// 请求超时时间
const requestTimeout = Duration(seconds: 5);

final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('Must be overridden in main');
});

final configProvider = StateNotifierProvider<ConfigNotifier, UserConfig>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ConfigNotifier(storage);
});

class ConfigNotifier extends StateNotifier<UserConfig> {
  final StorageService _storage;

  ConfigNotifier(this._storage)
    : super(
        UserConfig(
          semesterStartDate: semesterStartDate,
          studentId: _storage.getStudentId(),
          studentName: _storage.getStudentName(),
        ),
      );

  void updateFromLogin({
    required String studentId,
    required String studentName,
  }) {
    _storage.setStudentId(studentId);
    _storage.setStudentName(studentName);
    state = state.copyWith(studentId: studentId, studentName: studentName);
  }

  Future<void> logout() async {
    await _storage.clearCredentials();
    await _storage.clearCourses();
    state = UserConfig(semesterStartDate: semesterStartDate);
  }
}
