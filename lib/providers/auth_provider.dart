import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/cas_service.dart';
import '../services/control_service.dart';
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
  @override
  AuthState build() => const AuthState();

  Future<(LoginResult, ExamResult)?> login(
    String studentId,
    String password,
  ) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final authService = AuthService();
      final (login, exams) = await authService.loginAndFetchAll(
        studentId,
        password,
      );
      state = AuthState(
        status: AuthStatus.success,
        courses: login.courses,
        studentId: login.studentId,
        studentName: login.studentName,
      );
      unawaited(
        ControlService.instance.syncAfterOaLogin(
          studentId: login.studentId ?? studentId,
          displayName: login.studentName ?? '',
        ),
      );
      return (login, exams);
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
