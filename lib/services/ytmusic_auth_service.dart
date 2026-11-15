/*
 * FluentMusic — YouTube Music account session
 *
 * Owns the signed-in YouTube Music session:
 *   - validates the WebView cookie against `account/account_menu`
 *   - resolves the account `dataSyncId` from `account/accounts_list`
 *   - persists cookie + visitorData + dataSyncId + profile in secure storage
 *   - exposes an [InnerTubeAuth] for other services
 *
 * The cookie is never written to Hive, logs or analytics.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:musify/services/innertube_client.dart';

enum YtMusicAuthStatus { signedOut, connecting, connected, expired, error }

@immutable
class YtMusicProfile {
  const YtMusicProfile({
    required this.name,
    this.email,
    this.channelHandle,
    this.avatarUrl,
  });

  final String name;
  final String? email;
  final String? channelHandle;
  final String? avatarUrl;
}

class YtMusicAuthException implements Exception {
  YtMusicAuthException(this.userMessage, {this.cause});

  /// Safe to show in the UI. Never contains cookies or tokens.
  final String userMessage;
  final Object? cause;

  @override
  String toString() => 'YtMusicAuthException: $userMessage';
}

class YtMusicAuthService extends ChangeNotifier {
  YtMusicAuthService({InnerTubeClient? client, FlutterSecureStorage? storage})
    : _client = client ?? InnerTubeClient(),
      _storage = storage ?? const FlutterSecureStorage();

  final InnerTubeClient _client;
  final FlutterSecureStorage _storage;

  static const String _kCookie = 'ytm_cookie';
  static const String _kVisitor = 'ytm_visitor_data';
  static const String _kDataSyncId = 'ytm_datasync_id';
  static const String _kName = 'ytm_account_name';
  static const String _kEmail = 'ytm_account_email';
  static const String _kHandle = 'ytm_account_handle';
  static const String _kAvatar = 'ytm_account_avatar';

  YtMusicAuthStatus _status = YtMusicAuthStatus.signedOut;
  YtMusicProfile? _profile;
  InnerTubeAuth _auth = const InnerTubeAuth.empty();
  String? _lastError;
  bool _loaded = false;

  YtMusicAuthStatus get status => _status;
  YtMusicProfile? get profile => _profile;
  InnerTubeAuth get auth => _auth;
  String? get lastError => _lastError;

  bool get isConnected => _status == YtMusicAuthStatus.connected;
  bool get isBusy => _status == YtMusicAuthStatus.connecting;

  /// Reads the persisted session once. Safe to call repeatedly.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final values = await Future.wait([
        _storage.read(key: _kCookie),
        _storage.read(key: _kVisitor),
        _storage.read(key: _kDataSyncId),
        _storage.read(key: _kName),
        _storage.read(key: _kEmail),
        _storage.read(key: _kHandle),
        _storage.read(key: _kAvatar),
      ]);

      final cookie = values[0];
      final dataSyncId = values[2];
      if (!hasCompleteYouTubeLoginCookies(cookie)) {
        _setSignedOut(notify: false);
        return;
      }

      _auth = InnerTubeAuth(
        cookie: cookie,
        visitorData: values[1],
        dataSyncId: dataSyncId,
      );

      final name = values[3];
      _profile = (name == null || name.isEmpty)
          ? null
          : YtMusicProfile(
              name: name,
              email: values[4],
              channelHandle: values[5],
              avatarUrl: values[6],
            );

      // A cookie without a resolved dataSyncId cannot make account-bound
      // calls; keep it and ask the user to reconnect instead of pretending.
      _status = (dataSyncId == null || dataSyncId.isEmpty)
          ? YtMusicAuthStatus.expired
          : YtMusicAuthStatus.connected;
      _lastError = _status == YtMusicAuthStatus.expired
          ? 'YouTube Music session is incomplete. Reconnect your account.'
          : null;
      notifyListeners();
    } catch (error) {
      _lastError = 'Could not read the saved YouTube Music session.';
      _status = YtMusicAuthStatus.error;
      notifyListeners();
      debugPrint('YtMusicAuthService.load failed: ${error.runtimeType}');
    }
  }

  /// Validates [cookie] and persists the session.
  ///
  /// [dataSyncId] is optional: when absent it is resolved through
  /// `account/accounts_list`, exactly like the Kotlin reference.
  Future<void> completeLogin({
    required String cookie,
    String? visitorData,
    String? dataSyncId,
  }) async {
    final normalizedCookie = cookie.trim();
    if (!hasCompleteYouTubeLoginCookies(normalizedCookie)) {
      throw YtMusicAuthException(
        'The YouTube Music login did not finish. Sign in again.',
      );
    }

    _status = YtMusicAuthStatus.connecting;
    _lastError = null;
    notifyListeners();

    try {
      // Verify the cookie with the account menu first. The reference runs this
      // pass without a dataSyncId so a wrong/stale page id cannot mask a bad
      // cookie.
      final verificationAuth = InnerTubeAuth(
        cookie: normalizedCookie,
        visitorData: _normalize(visitorData),
      );
      final menu = await _client.post(
        'account/account_menu',
        {'context': _client.buildContext(verificationAuth)},
        auth: verificationAuth,
        authenticated: true,
      );
      final profile = _parseAccountMenu(menu);

      final resolvedDataSyncId =
          _normalizeDataSyncId(dataSyncId) ??
          await _fetchDataSyncId(verificationAuth);

      if (resolvedDataSyncId == null || resolvedDataSyncId.isEmpty) {
        throw YtMusicAuthException(
          'Signed in, but YouTube Music did not return an account id. '
          'Try again from the Account page.',
        );
      }

      final auth = InnerTubeAuth(
        cookie: normalizedCookie,
        visitorData: verificationAuth.visitorData,
        dataSyncId: resolvedDataSyncId,
      );

      await _persist(auth: auth, profile: profile);

      _auth = auth;
      _profile = profile;
      _status = YtMusicAuthStatus.connected;
      _lastError = null;
      notifyListeners();
    } on InnerTubeAuthException catch (error) {
      _status = YtMusicAuthStatus.error;
      _lastError = 'YouTube Music rejected the login. Sign in again.';
      notifyListeners();
      throw YtMusicAuthException(_lastError!, cause: error);
    } on YtMusicAuthException {
      _status = YtMusicAuthStatus.error;
      _lastError = 'Could not finish YouTube Music sign-in.';
      notifyListeners();
      rethrow;
    } catch (error) {
      _status = YtMusicAuthStatus.error;
      _lastError = 'Could not reach YouTube Music. Check your connection.';
      notifyListeners();
      throw YtMusicAuthException(_lastError!, cause: error);
    }
  }

  /// Re-validates the stored session. Returns false when it expired.
  Future<bool> refreshProfile() async {
    if (!_auth.hasLoginCookie) {
      _setSignedOut();
      return false;
    }

    try {
      final menu = await _client.post(
        'account/account_menu',
        {'context': _client.buildContext(_auth)},
        auth: _auth,
        authenticated: true,
      );
      final profile = _parseAccountMenu(menu);
      _profile = profile;
      await _persist(auth: _auth, profile: profile);
      _status = YtMusicAuthStatus.connected;
      _lastError = null;
      notifyListeners();
      return true;
    } on InnerTubeAuthException {
      markExpired();
      return false;
    } catch (error) {
      _lastError = 'Could not refresh the YouTube Music session.';
      _status = YtMusicAuthStatus.error;
      notifyListeners();
      debugPrint('YtMusicAuthService.refreshProfile failed: '
          '${error.runtimeType}');
      return false;
    }
  }

  void markExpired() {
    if (_status == YtMusicAuthStatus.signedOut) return;
    _status = YtMusicAuthStatus.expired;
    _lastError = 'YouTube Music session expired. Reconnect your account.';
    notifyListeners();
  }

  Future<void> signOut() async {
    _auth = const InnerTubeAuth.empty();
    _profile = null;
    _status = YtMusicAuthStatus.signedOut;
    _lastError = null;
    notifyListeners();

    try {
      await Future.wait([
        _storage.delete(key: _kCookie),
        _storage.delete(key: _kVisitor),
        _storage.delete(key: _kDataSyncId),
        _storage.delete(key: _kName),
        _storage.delete(key: _kEmail),
        _storage.delete(key: _kHandle),
        _storage.delete(key: _kAvatar),
      ]);
    } catch (error) {
      debugPrint('YtMusicAuthService.signOut partially failed: '
          '${error.runtimeType}');
    }
  }

  Future<String?> _fetchDataSyncId(InnerTubeAuth auth) async {
    final response = await _client.post(
      'account/accounts_list',
      {'context': _client.buildContext(auth)},
      auth: auth,
      authenticated: true,
    );
    return _findDataSyncId(response);
  }

  Future<void> _persist({
    required InnerTubeAuth auth,
    required YtMusicProfile profile,
  }) async {
    await Future.wait([
      _storage.write(key: _kCookie, value: auth.cookie),
      _storage.write(key: _kVisitor, value: auth.visitorData),
      _storage.write(key: _kDataSyncId, value: auth.dataSyncId),
      _storage.write(key: _kName, value: profile.name),
      _storage.write(key: _kEmail, value: profile.email),
      _storage.write(key: _kHandle, value: profile.channelHandle),
      _storage.write(key: _kAvatar, value: profile.avatarUrl),
    ]);
  }

  void _setSignedOut({bool notify = true}) {
    _auth = const InnerTubeAuth.empty();
    _profile = null;
    _status = YtMusicAuthStatus.signedOut;
    _lastError = null;
    if (notify) notifyListeners();
  }

  YtMusicProfile _parseAccountMenu(Map<String, dynamic> response) {
    final actions = response['actions'];
    if (actions is List) {
      for (final action in actions) {
        if (action is! Map) continue;
        final header = _map(
          _map(
            _map(
              _map(action, 'openPopupAction'),
              'popup',
            ),
            'multiPageMenuRenderer',
          ),
          'header',
        );
        final active = _map(header, 'activeAccountHeaderRenderer');
        if (active == null) continue;

        final name = _runsText(active['accountName']);
        if (name == null || name.isEmpty) continue;

        return YtMusicProfile(
          name: name,
          email: _runsText(active['email']),
          channelHandle: _runsText(active['channelHandle']),
          avatarUrl: _lastThumbnail(active['accountPhoto']),
        );
      }
    }

    throw YtMusicAuthException(
      'YouTube Music did not return an account. Sign in again.',
    );
  }

  /// Finds the first `dataSyncId` / `datasyncId` string in the response.
  String? _findDataSyncId(dynamic node) {
    if (node is Map) {
      for (final key in const ['dataSyncId', 'datasyncId']) {
        final value = node[key];
        final normalized = _normalizeDataSyncId(
          value is String ? value : value?.toString(),
        );
        if (normalized != null && normalized.isNotEmpty) return normalized;
      }
      for (final value in node.values) {
        final found = _findDataSyncId(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findDataSyncId(value);
        if (found != null) return found;
      }
    }
    return null;
  }
}

Map<String, dynamic>? _map(dynamic node, String key) {
  if (node is! Map) return null;
  final value = node[key];
  return value is Map ? value.cast<String, dynamic>() : null;
}

String? _runsText(dynamic node) {
  if (node is! Map) return null;
  final runs = node['runs'];
  if (runs is List) {
    final text = runs
        .whereType<Map>()
        .map((run) => run['text']?.toString() ?? '')
        .join()
        .trim();
    if (text.isNotEmpty) return text;
  }
  final simple = node['simpleText']?.toString().trim();
  return (simple == null || simple.isEmpty) ? null : simple;
}

String? _lastThumbnail(dynamic node) {
  if (node is! Map) return null;
  final thumbnails = node['thumbnails'];
  if (thumbnails is! List || thumbnails.isEmpty) return null;
  for (final thumbnail in thumbnails.reversed) {
    if (thumbnail is! Map) continue;
    final url = thumbnail['url']?.toString();
    if (url != null && url.isNotEmpty) return url;
  }
  return null;
}

String? _normalize(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.toLowerCase() == 'null') return null;
  return trimmed;
}

String? _normalizeDataSyncId(String? value) {
  final trimmed = _normalize(value);
  if (trimmed == null) return null;

  var decoded = trimmed;
  if (decoded.contains('%')) {
    try {
      decoded = Uri.decodeComponent(decoded);
    } catch (_) {
      // Keep the raw value when it is not valid percent-encoding.
    }
  }

  final parts = decoded.split('||').map((part) => part.trim()).toList();
  if (parts.length < 2) {
    return decoded.trim().isEmpty ? null : decoded.trim();
  }
  final delegated = parts.first;
  final session = parts.sublist(1).join('||').trim();
  if (delegated.isEmpty) return session.isEmpty ? null : session;
  if (session.isEmpty) return delegated;
  return '$delegated||$session';
}

/// App-wide session instance.
final YtMusicAuthService ytMusicAuthService = YtMusicAuthService();
