import 'dart:convert';

import '../core/network/auth_api.dart';
import '../core/storage/token_storage.dart';
import '../models/user.dart';

class AuthRepository {
  final AuthApi authApi;
  final TokenStorage tokenStorage;

  AuthRepository({required this.authApi, required this.tokenStorage});

  Future<bool> isLoggedIn() async => (await tokenStorage.readAccessToken()) != null;

  Future<AppUser?> currentUser() async {
    final json = await tokenStorage.readUserJson();
    if (json == null) return null;
    return AppUser.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<AppUser> login({required String identifier, required String password}) async {
    final tokens = await authApi.login(identifier: identifier, password: password);
    await tokenStorage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      userJson: jsonEncode(tokens.user.toJson()),
    );
    return tokens.user;
  }

  Future<void> logout() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await authApi.logout(refreshToken: refreshToken);
      } catch (_) {
        // Best-effort: the agent may be offline. Clearing local tokens below
        // still logs the device out; the server-side token simply expires
        // naturally rather than being explicitly revoked.
      }
    }
    await tokenStorage.clear();
  }
}
