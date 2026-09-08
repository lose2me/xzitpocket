import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../models/app_settings.dart';
import 'app_settings_provider.dart';
import 'config_provider.dart';
import '../services/auth_service.dart';
import '../services/cas_service.dart';
import '../services/preferences_storage.dart';
import '../services/talker.dart';

enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final List<Course>? courses;
  final String? studentId;
  final String? studentName;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.courses,
    this.studentId,
    this.studentName,
  });
}

class AuthNotifier extends Notifier<AuthState> {
  late PreferencesStorage _storage;

  @override
  AuthState build() {
    _storage = ref.watch(preferencesStorageProvider);
    return const AuthState();
  }

  Future<(LoginResult, ExamResult?, GradeResult?, AcademicStatus?)?> login(
    String studentId,
    String password,
  ) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final authService = AuthService();
      final hidden = ref.read(appSettingsProvider).hiddenServiceFeatures;
      bool enabled(AppServiceFeature feature) => !hidden.contains(feature);
      final (login, exams, grades, academic) = await authService
          .loginAndFetchAll(
            studentId,
            password,
            fetchExams: enabled(AppServiceFeature.exams),
            fetchGrades: enabled(AppServiceFeature.academic),
            fetchAcademic: enabled(AppServiceFeature.academic),
          );
      final cacheWrites = <Future<void>>[];
      if (exams != null) {
        cacheWrites.add(_storage.setExamCache(jsonEncode(exams.toJson())));
      }
      if (grades != null) {
        cacheWrites.add(_storage.setGradeCache(jsonEncode(grades.toJson())));
      }
      if (academic != null) {
        cacheWrites.add(
          _storage.setAcademicCache(jsonEncode(academic.toJson())),
        );
      }
      await Future.wait(cacheWrites);
      state = AuthState(
        status: AuthStatus.success,
        courses: login.courses,
        studentId: login.studentId,
        studentName: login.studentName,
      );
      return (login, exams, grades, academic);
    } on AuthException catch (e, stackTrace) {
      talker.error('登录失败', e, stackTrace);
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
      return null;
    } catch (e, stackTrace) {
      talker.error('登录异常', e, stackTrace);
      state = AuthState(status: AuthStatus.error, errorMessage: '登录失败: $e');
      return null;
    }
  }

  void reset() {
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
