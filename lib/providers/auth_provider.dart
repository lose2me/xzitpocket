import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/course.dart';
import '../services/auth_service.dart';

enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String? errorMessage;
  final Dio? authenticatedDio;
  final List<Course>? courses;
  final String? studentId;
  final String? studentName;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.authenticatedDio,
    this.courses,
    this.studentId,
    this.studentName,
  });
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  Future<LoginResult?> login(String studentId, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final authService = AuthService();
      final result = await authService.loginAndFetch(studentId, password);
      state = AuthState(
        status: AuthStatus.success,
        authenticatedDio: result.dio,
        courses: result.courses,
        studentId: result.studentId,
        studentName: result.studentName,
      );
      return result;
    } on AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
      return null;
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: '登录失败: $e');
      return null;
    }
  }

  void reset() {
    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
