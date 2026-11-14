/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musify/services/logger_service.dart';

/// Optional Supabase configuration.
///
/// Pass keys at build time:
/// `flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
///
/// With no keys the app runs in local mode: every feature works, cloud sync is
/// simply unavailable and the UI says so. An account is never required.
final class CloudSyncConfig {
  CloudSyncConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static String get _base {
    final url = supabaseUrl.trim();
    if (url.endsWith('/')) return url.substring(0, url.length - 1);
    return url;
  }

  static String get authBase => '$_base/auth/v1';
  static String get restBase => '$_base/rest/v1';

  static bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}

/// The signed-in identity. Local mode uses [isLocal] and no tokens.
@immutable
class AccountSession {
  const AccountSession({
    required this.userId,
    required this.email,
    required this.name,
    this.accessToken = '',
    this.refreshToken = '',
    this.expiresAt = 0,
    this.isLocal = false,
  });

  final String userId;
  final String email;
  final String name;
  final String accessToken;
  final String refreshToken;

  /// Unix epoch milliseconds. `0` for local sessions.
  final int expiresAt;

  final bool isLocal;

  bool get isCloud => !isLocal;

  bool get isExpired {
    if (isLocal) return false;
    return DateTime.now().millisecondsSinceEpoch >= expiresAt - 60000;
  }

  String get initial {
    final source = name.trim().isNotEmpty ? name.trim() : email.trim();
    if (source.isEmpty) return 'F';
    return String.fromCharCode(source.runes.first).toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'userId': userId,
        'email': email,
        'name': name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
        'isLocal': isLocal,
      };

  factory AccountSession.fromJson(Map<dynamic, dynamic> json) {
    return AccountSession(
      userId: json['userId']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
      isLocal: json['isLocal'] == true,
    );
  }
}

/// A tiny result wrapper so the UI can show honest, non-crashing messages.
@immutable
class AccountResult {
  const AccountResult(this.success, this.message);

  final bool success;
  final String message;

  static const AccountResult ok = AccountResult(true, '');
}

/// Optional account service. Never blocks the app, never gates a feature.
class AccountService extends ChangeNotifier {
  AccountService._();

  static final AccountService instance = AccountService._();

  static const String _storageKey = 'accountSession';

  AccountSession? _session;
  bool _busy = false;
  String? _lastError;

  AccountSession? get session => _session;
  bool get isSignedIn => _session != null;
  bool get isCloudAccount => _session?.isCloud ?? false;
  bool get isBusy => _busy;
  String? get lastError => _lastError;

  String get displayName {
    final current = _session;
    if (current == null) return 'Guest';
    if (current.name.trim().isNotEmpty) return current.name.trim();
    if (current.email.trim().isNotEmpty) return current.email.trim();
    return 'Listener';
  }

  String get displayEmail {
    final current = _session;
    if (current == null) return 'No account needed';
    if (current.isLocal) return 'Local profile · private mode';
    return current.email;
  }

  /// Reads the persisted session. Call after Hive boxes are open.
  void restoreFromStorage() {
    try {
      final raw = Hive.box('settings').get(_storageKey);
      if (raw is String && raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _session = AccountSession.fromJson(decoded);
        }
      }
    } catch (e, stackTrace) {
      logger.log('Account session restore failed', error: e, stackTrace: stackTrace);
    }
    notifyListeners();
  }

  Future<void> _persist(AccountSession? session) async {
    _session = session;
    final box = Hive.box('settings');
    if (session == null) {
      await box.delete(_storageKey);
    } else {
      await box.put(_storageKey, jsonEncode(session.toJson()));
    }
    notifyListeners();
  }

  Future<AccountResult> signInLocal(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return const AccountResult(false, 'Enter a display name first');
    }
    _setBusy(true);
    try {
      await _persist(
        AccountSession(
          userId: 'local',
          email: '',
          name: cleanName,
          isLocal: true,
        ),
      );
      return const AccountResult(true, 'Local profile ready');
    } finally {
      _setBusy(false);
    }
  }

  /// Supabase email/password sign-in, plus a friendly fallback in local mode.
  Future<AccountResult> signIn({
    required String email,
    required String password,
  }) async {
    if (!CloudSyncConfig.isConfigured) {
      return const AccountResult(
        false,
        'Cloud sync is not configured in this build',
      );
    }
    if (email.trim().isEmpty || password.isEmpty) {
      return const AccountResult(false, 'Email and password are required');
    }

    _setBusy(true);
    try {
      final response = await http
          .post(
            Uri.parse('${CloudSyncConfig.authBase}/token?grant_type=password'),
            headers: _authHeaders,
            body: jsonEncode(<String, String>{
              'email': email.trim(),
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AccountResult(false, _errorFrom(response, 'Sign-in failed'));
      }

      final session = _sessionFromAuthResponse(response.body);
      if (session == null) {
        return const AccountResult(false, 'Unexpected sign-in response');
      }
      await _persist(session);
      return const AccountResult(true, 'Signed in');
    } on TimeoutException {
      return const AccountResult(false, 'Network timed out. Try again');
    } catch (e, stackTrace) {
      logger.log('Sign in failed', error: e, stackTrace: stackTrace);
      return AccountResult(false, 'Sign-in failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  /// Creates a Supabase account. Email confirmation may still be required.
  Future<AccountResult> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!CloudSyncConfig.isConfigured) {
      return const AccountResult(
        false,
        'Cloud sync is not configured in this build',
      );
    }
    if (email.trim().isEmpty || password.isEmpty) {
      return const AccountResult(false, 'Email and password are required');
    }

    _setBusy(true);
    try {
      final response = await http
          .post(
            Uri.parse('${CloudSyncConfig.authBase}/signup'),
            headers: _authHeaders,
            body: jsonEncode(<String, dynamic>{
              'email': email.trim(),
              'password': password,
              if (name.trim().isNotEmpty) 'data': <String, String>{
                'name': name.trim(),
              },
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AccountResult(false, _errorFrom(response, 'Sign-up failed'));
      }

      final session = _sessionFromAuthResponse(response.body);
      if (session == null) {
        return const AccountResult(
          true,
          'Account created. Check your email, then sign in',
        );
      }
      await _persist(session);
      return const AccountResult(true, 'Account created');
    } on TimeoutException {
      return const AccountResult(false, 'Network timed out. Try again');
    } catch (e, stackTrace) {
      logger.log('Sign up failed', error: e, stackTrace: stackTrace);
      return AccountResult(false, 'Sign-up failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    await _persist(null);
    try {
      await Hive.box('settings').delete('syncLastAt');
    } catch (_) {}
  }

  /// Returns a usable cloud token, refreshing it when needed. Null in local
  /// mode or when the refresh fails.
  Future<String?> validAccessToken() async {
    final current = _session;
    if (current == null || current.isLocal) return null;
    if (!current.isExpired) return current.accessToken;
    if (current.refreshToken.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse(
              '${CloudSyncConfig.authBase}/token?grant_type=refresh_token',
            ),
            headers: _authHeaders,
            body: jsonEncode(<String, String>{
              'refresh_token': current.refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final refreshed = _sessionFromAuthResponse(response.body);
      if (refreshed == null) return null;
      await _persist(refreshed);
      return refreshed.accessToken;
    } catch (e, stackTrace) {
      logger.log('Token refresh failed', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  void _setBusy(bool value) {
    _busy = value;
    if (value) _lastError = null;
    notifyListeners();
  }

  AccountSession? _sessionFromAuthResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final user = decoded['user'];
      if (user is! Map) return null;
      final metadata = user['user_metadata'];
      final name = metadata is Map
          ? (metadata['name'] ?? metadata['full_name'] ?? '').toString()
          : '';
      final expiresIn = (decoded['expires_in'] as num?)?.toInt() ?? 3600;

      return AccountSession(
        userId: user['id']?.toString() ?? '',
        email: user['email']?.toString() ?? '',
        name: name,
        accessToken: decoded['access_token']?.toString() ?? '',
        refreshToken: decoded['refresh_token']?.toString() ?? '',
        expiresAt: DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch,
      );
    } catch (e, stackTrace) {
      logger.log(
        'Could not parse auth response',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Map<String, String> get _authHeaders => <String, String>{
        'apikey': CloudSyncConfig.supabaseAnonKey,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  String _errorFrom(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['msg'] ??
            decoded['message'] ??
            decoded['error_description'] ??
            decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString();
        }
      }
    } catch (_) {}
    return '$fallback (HTTP ${response.statusCode})';
  }
}

final accountService = AccountService.instance;
