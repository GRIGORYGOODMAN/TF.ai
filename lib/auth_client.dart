import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'online_catalog_client.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  final String id;
  final String email;

  String get displayName {
    final trimmed = email.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) {
      return 'Account';
    }
    return trimmed.split('@').first;
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'email': email};
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'];
    return AuthSession(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresAt:
          DateTime.tryParse(json['expires_at'] as String? ?? '') ??
          DateTime.now(),
      user: userJson is Map<String, dynamic>
          ? AuthUser.fromJson(userJson)
          : const AuthUser(id: '', email: ''),
    );
  }

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final AuthUser user;

  bool get isSignedIn => accessToken.trim().isNotEmpty && user.id.isNotEmpty;

  bool get shouldRefresh {
    return expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 5)));
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      'expires_at': expiresAt.toIso8601String(),
      'user': user.toJson(),
    };
  }
}

class AuthResult {
  const AuthResult({required this.message, this.session});

  final String message;
  final AuthSession? session;
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseAuthClient {
  SupabaseAuthClient({
    this.projectUrl = supabaseProjectUrl,
    this.publishableKey = supabasePublishableKey,
  });

  static const _sessionKey = 'tf_ai.auth.v1';

  final String projectUrl;
  final String publishableKey;

  String get _normalizedProjectUrl => projectUrl.replaceAll(RegExp(r'/$'), '');

  Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final session = AuthSession.fromJson(decoded);
      if (!session.isSignedIn) {
        await clearSession();
        return null;
      }
      if (session.shouldRefresh) {
        return refreshSession(session);
      }
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<AuthResult> signUp({
    required String email,
    required String password,
  }) async {
    final decoded = await _postAuth(
      '/auth/v1/signup',
      body: {'email': email.trim(), 'password': password},
    );
    final session = _sessionFromResponse(decoded);
    if (session != null) {
      await saveSession(session);
      return AuthResult(message: 'Account created', session: session);
    }

    return const AuthResult(
      message: 'Account created. Confirm email if Supabase asks for it.',
    );
  }

  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final decoded = await _postAuth(
      '/auth/v1/token',
      queryParameters: {'grant_type': 'password'},
      body: {'email': email.trim(), 'password': password},
    );
    final session = _sessionFromResponse(decoded);
    if (session == null) {
      throw const AuthException('Sign in response did not include a session.');
    }

    await saveSession(session);
    return session;
  }

  Future<AuthSession> refreshSession(AuthSession session) async {
    if (session.refreshToken.trim().isEmpty) {
      throw const AuthException('Missing refresh token.');
    }

    final decoded = await _postAuth(
      '/auth/v1/token',
      queryParameters: {'grant_type': 'refresh_token'},
      body: {'refresh_token': session.refreshToken},
    );
    final refreshed = _sessionFromResponse(decoded);
    if (refreshed == null) {
      throw const AuthException('Refresh response did not include a session.');
    }

    await saveSession(refreshed);
    return refreshed;
  }

  Future<void> signOut(AuthSession? session) async {
    if (session != null && session.accessToken.trim().isNotEmpty) {
      try {
        await _postAuth(
          '/auth/v1/logout',
          authorizationToken: session.accessToken,
        );
      } catch (_) {
        // Local sign out still matters if the network is unavailable.
      }
    }
    await clearSession();
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  Future<Map<String, dynamic>> _postAuth(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
    String? authorizationToken,
  }) async {
    final uri = Uri.parse(
      '$_normalizedProjectUrl$path',
    ).replace(queryParameters: queryParameters);
    final encodedBody = body == null ? '' : jsonEncode(body);

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set('apikey', publishableKey)
        ..set(
          'Authorization',
          'Bearer ${authorizationToken?.trim().isNotEmpty == true ? authorizationToken!.trim() : publishableKey}',
        )
        ..set(HttpHeaders.acceptHeader, 'application/json');

      if (encodedBody.isNotEmpty) {
        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
        request.write(encodedBody);
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      final decoded = responseBody.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(_errorMessage(decoded, responseBody));
      }

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } on SocketException catch (error) {
      throw AuthException('Network error: ${error.message}');
    } on FormatException catch (error) {
      throw AuthException('Invalid auth response: ${error.message}');
    } finally {
      client.close(force: true);
    }
  }

  AuthSession? _sessionFromResponse(Map<String, dynamic> json) {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    final userJson = json['user'];
    if (accessToken == null ||
        accessToken.trim().isEmpty ||
        refreshToken == null ||
        refreshToken.trim().isEmpty ||
        userJson is! Map<String, dynamic>) {
      return null;
    }

    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresAt: _expiresAt(json),
      user: AuthUser.fromJson(userJson),
    );
  }

  DateTime _expiresAt(Map<String, dynamic> json) {
    final rawExpiresAt = json['expires_at'];
    if (rawExpiresAt is int && rawExpiresAt > 0) {
      return DateTime.fromMillisecondsSinceEpoch(rawExpiresAt * 1000);
    }

    final expiresIn = json['expires_in'];
    if (expiresIn is int && expiresIn > 0) {
      return DateTime.now().add(Duration(seconds: expiresIn));
    }

    return DateTime.now().add(const Duration(hours: 1));
  }

  String _errorMessage(Object? decoded, String responseBody) {
    if (decoded is Map<String, dynamic>) {
      final message = decoded['msg'] ?? decoded['message'] ?? decoded['error'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    return responseBody.trim().isEmpty
        ? 'Authentication failed.'
        : responseBody;
  }
}
