/*
 * FluentMusic — YouTube Music InnerTube client
 *
 * Minimal authenticated client for the YouTube Music (WEB_REMIX) endpoints we
 * need for account sign-in, profile validation and (later) library sync.
 *
 * The header contract mirrors the Kotlin reference:
 *   - X-Origin / Referer / X-YouTube-Client-Name / X-YouTube-Client-Version
 *   - X-Goog-Visitor-Id
 *   - cookie (only for authenticated calls)
 *   - Authorization: SAPISIDHASH <ts>_<sha1("<ts> <SAPISID> <origin>")>
 *   - X-Goog-AuthUser: 0
 *   - X-Goog-PageId: part before "||" in dataSyncId
 *
 * Nothing here reads or logs the cookie except to build headers.
 */

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// Session values used to authenticate InnerTube requests.
class InnerTubeAuth {
  const InnerTubeAuth({
    this.cookie,
    this.visitorData,
    this.dataSyncId,
  });

  const InnerTubeAuth.empty()
    : cookie = null,
      visitorData = null,
      dataSyncId = null;

  final String? cookie;
  final String? visitorData;

  /// May be `pageId||userSessionId`.
  final String? dataSyncId;

  bool get hasLoginCookie => _sapisidCookie(cookie) != null;

  /// Delegated page/session id sent as `X-Goog-PageId`.
  String? get pageId {
    final value = dataSyncId?.trim();
    if (value == null || value.isEmpty) return null;
    final index = value.indexOf('||');
    if (index <= 0) return null;
    final id = value.substring(0, index).trim();
    return id.isEmpty ? null : id;
  }

  InnerTubeAuth copyWith({
    String? cookie,
    String? visitorData,
    String? dataSyncId,
  }) {
    return InnerTubeAuth(
      cookie: cookie ?? this.cookie,
      visitorData: visitorData ?? this.visitorData,
      dataSyncId: dataSyncId ?? this.dataSyncId,
    );
  }
}

/// Base InnerTube failure.
class InnerTubeException implements Exception {
  InnerTubeException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'InnerTubeException(${statusCode ?? '?'}): $message';
}

/// Session is missing, incomplete or rejected (HTTP 401).
class InnerTubeAuthException extends InnerTubeException {
  InnerTubeAuthException(super.message, {super.statusCode});
}

/// Thin authenticated HTTP client for `music.youtube.com/youtubei/v1/...`.
class InnerTubeClient {
  InnerTubeClient({http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 15);

  final http.Client _httpClient;
  final Duration _timeout;

  static const String origin = 'https://music.youtube.com';
  static const String referer = '$origin/';
  static const String apiBase = '$origin/youtubei/v1';

  // WEB_REMIX profile from the Kotlin client catalog.
  static const String clientName = 'WEB_REMIX';
  static const String clientId = '67';
  static const String clientVersion = '1.20260707.12.00';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:140.0) '
      'Gecko/20100101 Firefox/140.0';

  /// Builds the request context for a WEB_REMIX call.
  Map<String, dynamic> buildContext(InnerTubeAuth auth) {
    final pageId = auth.pageId;

    return {
      'client': {
        'clientName': clientName,
        'clientVersion': clientVersion,
        'hl': 'en',
        'gl': 'IN',
        if (auth.visitorData != null && auth.visitorData!.isNotEmpty)
          'visitorData': auth.visitorData,
      },
      if (pageId != null)
        'user': {
          'onBehalfOfUser': pageId,
        },
    };
  }

  /// Posts [body] to [endpoint] and returns the decoded JSON object.
  ///
  /// Set [authenticated] for account-bound endpoints (account menu, accounts
  /// list, likes, library). Throws [InnerTubeAuthException] for 401/403 so the
  /// caller can mark the session as expired.
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    InnerTubeAuth auth = const InnerTubeAuth.empty(),
    bool authenticated = false,
  }) async {
    final uri = Uri.parse('$apiBase/$endpoint').replace(
      queryParameters: const {'prettyPrint': 'false'},
    );

    try {
      final response = await _httpClient
          .post(
            uri,
            headers: _headers(auth, authenticated: authenticated),
            body: jsonEncode(body),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw InnerTubeAuthException(
          'YouTube Music rejected the session',
          statusCode: response.statusCode,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw InnerTubeException(
          'Request failed',
          statusCode: response.statusCode,
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw InnerTubeException('Unexpected response shape');
      }
      return decoded.cast<String, dynamic>();
    } on TimeoutException {
      throw InnerTubeException('Request timed out');
    } on InnerTubeException {
      rethrow;
    } catch (error) {
      throw InnerTubeException('Network error: $error');
    }
  }

  Map<String, String> _headers(
    InnerTubeAuth auth, {
    required bool authenticated,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': userAgent,
      'X-Goog-Api-Format-Version': '1',
      'X-YouTube-Client-Name': clientId,
      'X-YouTube-Client-Version': clientVersion,
      'X-Origin': origin,
      'Referer': referer,
    };

    final visitorData = auth.visitorData;
    if (visitorData != null && visitorData.isNotEmpty) {
      headers['X-Goog-Visitor-Id'] = visitorData;
    }

    if (!authenticated) return headers;

    final cookie = auth.cookie?.trim();
    if (cookie == null || cookie.isEmpty) return headers;

    headers['cookie'] = cookie;

    final sapisid = _sapisidCookie(cookie);
    if (sapisid != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final hash = sha1
          .convert(utf8.encode('$timestamp $sapisid $origin'))
          .toString();
      headers['Authorization'] = 'SAPISIDHASH ${timestamp}_$hash';
      headers['X-Goog-AuthUser'] = '0';
    }

    final pageId = auth.pageId;
    if (pageId != null) {
      headers['X-Goog-PageId'] = pageId;
    }

    return headers;
  }

  void close() => _httpClient.close();
}

/// Parses a `k=v; k=v` cookie header into a map.
Map<String, String> parseCookieHeader(String? cookie) {
  final result = <String, String>{};
  final value = cookie?.trim();
  if (value == null || value.isEmpty) return result;

  for (final part in value.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final index = trimmed.indexOf('=');
    if (index <= 0) continue;
    final key = trimmed.substring(0, index).trim();
    final cookieValue = trimmed.substring(index + 1).trim();
    if (key.isEmpty || cookieValue.isEmpty) continue;
    result.putIfAbsent(key, () => cookieValue);
  }
  return result;
}

/// A complete YouTube login needs `LOGIN_INFO` plus one SAPISID variant.
bool hasCompleteYouTubeLoginCookies(String? cookie) {
  final map = parseCookieHeader(cookie);
  if ((map['LOGIN_INFO'] ?? '').isEmpty) return false;
  return _sapisidCookie(cookie) != null;
}

String? _sapisidCookie(String? cookie) {
  final map = parseCookieHeader(cookie);
  for (final name in const [
    'SAPISID',
    '__Secure-3PAPISID',
    '__Secure-1PAPISID',
  ]) {
    final value = map[name];
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}
