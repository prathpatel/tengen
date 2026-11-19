import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tengen/src/model/ogs/user.dart';
import 'package:tengen/src/network/http.dart';
import 'package:tengen/src/utils/json.dart';

const _cookiesKey = 'ogs.cookies';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

/// The OGS session: the signed in user (or a guest) and the JWT used by the realtime API.
@immutable
class AuthState {
  const AuthState({required this.user, required this.jwt});

  /// Parses the `ui/config` (or `/api/v0/login`) response.
  factory AuthState.fromConfig(Map<String, dynamic> config) => AuthState(
    user: OgsUser.fromJson(asMap(config['user']) ?? const {'id': 0, 'anonymous': true}),
    jwt: config['user_jwt'] as String? ?? '',
  );

  final OgsUser user;
  final String jwt;

  bool get isSignedIn => !user.anonymous && user.id > 0;
}

final authProvider = AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  OgsHttp get _http => ref.read(ogsHttpProvider);
  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  @override
  Future<AuthState> build() async {
    try {
      final saved = await _storage.read(key: _cookiesKey);
      if (saved != null) {
        _http.restoreCookies(
          (jsonDecode(saved) as Map).map((k, v) => MapEntry(k as String, v as String)),
        );
      }
    } on Object catch (e) {
      debugPrint('Could not restore the session: $e');
    }
    return await _fetchConfig();
  }

  Future<AuthState> _fetchConfig() async {
    final config = asMap(await _http.get('/api/v1/ui/config')) ?? const {};
    final auth = AuthState.fromConfig(config);
    if (!auth.isSignedIn) await _storage.delete(key: _cookiesKey);
    return auth;
  }

  Future<void> _saveCookies() => _storage.write(key: _cookiesKey, value: jsonEncode(_http.cookies));

  /// Signs in with an OGS username and password, as the OGS website does.
  ///
  /// Throws an [OgsHttpException] with the server's message when the credentials are refused.
  Future<void> signIn(String username, String password) async {
    // Fetch the config first to get a CSRF cookie.
    if (!_http.cookies.containsKey('csrftoken')) await _http.get('/api/v1/ui/config');
    final response = asMap(
      await _http.post('/api/v0/login', {'username': username.trim(), 'password': password}),
    );
    if (response == null || response['redirect'] != null) {
      throw const OgsHttpException(
        400,
        'This account signs in with a social login. Set a password on online-go.com first.',
      );
    }
    final auth = AuthState.fromConfig(response);
    if (!auth.isSignedIn) throw const OgsHttpException(401, 'Sign in failed');
    await _saveCookies();
    state = AsyncData(auth);
  }

  Future<void> signOut() async {
    try {
      await _http.post('/api/v0/logout', const <String, Object?>{});
    } on Object catch (e) {
      debugPrint('Logout request failed: $e');
    }
    _http.clearCookies();
    await _storage.delete(key: _cookiesKey);
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchConfig);
  }
}
