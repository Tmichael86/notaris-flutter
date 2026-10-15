import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_session.dart';
import '../services/auth_service.dart';

enum AuthStatus { loading, unauthenticated, authenticating, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.session,
    this.errorMessage,
  });

  final AuthStatus status;
  final AuthSession? session;
  final String? errorMessage;

  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.unauthenticated([String? error]) => AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: error,
      );
  factory AuthState.authenticating() =>
      const AuthState(status: AuthStatus.authenticating);
  factory AuthState.authenticated(AuthSession session) => AuthState(
        status: AuthStatus.authenticated,
        session: session,
      );
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.read(authServiceProvider));
  controller.initialize();
  return controller;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._service) : super(AuthState.loading());

  final AuthService _service;

  Future<void> initialize() async {
    try {
      final session = await _service.restoreSession();
      state = session == null
          ? AuthState.unauthenticated()
          : AuthState.authenticated(session);
    } catch (_) {
      state = AuthState.unauthenticated(
        'Sesi tersimpan tidak dapat dipulihkan. Silakan login kembali.',
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    state = AuthState.authenticating();
    try {
      final session = await _service.login(
        username: username,
        password: password,
        rememberMe: rememberMe,
      );
      state = AuthState.authenticated(session);
    } catch (error) {
      state = AuthState.unauthenticated(_service.messageFor(error));
    }
  }

  Future<void> logout() async {
    try {
      await _service.clearPersistedSession();
    } finally {
      state = AuthState.unauthenticated();
    }
  }
}
