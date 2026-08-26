import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/auth_api.dart';
import '../core/network/dio_client.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

const _nonAgentLoginMessage =
    'This app is for Revenue Agents only. Admins and Supervisors should use '
    'the web dashboard instead.';

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

/// dioProvider reads authControllerProvider.notifier lazily, inside the
/// onAuthFailure closure, not during this provider's own build - so there is
/// no build-time cycle even though AuthController itself depends on Dio (via
/// AuthRepository) to perform the login/refresh calls that feed it.
final dioProvider = Provider<Dio>((ref) {
  return buildDio(
    tokenStorage: ref.watch(tokenStorageProvider),
    onAuthFailure: () async {
      ref.read(authControllerProvider.notifier).handleAuthFailure();
    },
  );
});

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      authApi: ref.watch(authApiProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    ));

class AuthState {
  final bool isLoading;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({this.isLoading = true, this.user, this.errorMessage});

  bool get isLoggedIn => user != null;

  AuthState copyWith({bool? isLoading, AppUser? user, bool clearUser = false, String? errorMessage}) =>
      AuthState(
        isLoading: isLoading ?? this.isLoading,
        user: clearUser ? null : (user ?? this.user),
        errorMessage: errorMessage,
      );
}

class AuthController extends StateNotifier<AuthState> {
  final Ref ref;

  AuthController(this.ref) : super(const AuthState(isLoading: true)) {
    _bootstrap();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _bootstrap() async {
    final user = await _repo.currentUser();
    if (user != null && user.role != UserRole.agent) {
      // A non-agent session should never have been persisted in the first
      // place (see login() below), but guard against a stale one restored
      // from before this check existed.
      await _repo.logout();
      state = const AuthState(isLoading: false, user: null, errorMessage: _nonAgentLoginMessage);
      return;
    }
    state = AuthState(isLoading: false, user: user);
  }

  Future<void> login({required String identifier, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final user = await _repo.login(identifier: identifier, password: password);
      if (user.role != UserRole.agent) {
        // The backend has no role restriction on /auth/login (any active
        // account can obtain a token - role is enforced per-endpoint, not
        // at login), so this app is the one place that needs to say "this
        // tool is for agents." Log back out immediately rather than
        // leaving a non-agent session sitting in secure storage.
        await _repo.logout();
        state = const AuthState(isLoading: false, user: null, errorMessage: _nonAgentLoginMessage);
        return;
      }
      state = AuthState(isLoading: false, user: user);
    } on DioException catch (e) {
      state = AuthState(
        isLoading: false,
        errorMessage: _describeLoginError(e),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(isLoading: false, user: null);
  }

  void handleAuthFailure() {
    state = const AuthState(isLoading: false, user: null, errorMessage: 'Session expired. Please log in again.');
  }

  String _describeLoginError(DioException e) {
    if (e.response?.statusCode == 401) return 'Incorrect email/phone or password.';
    if (e.response?.statusCode == 429) return 'Too many attempts. Please wait and try again.';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return 'No connection to the server. Check your network and try again.';
    }
    return 'Login failed. Please try again.';
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);
