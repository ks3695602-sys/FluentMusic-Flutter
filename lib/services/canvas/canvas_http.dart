/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The small, deliberately plain HTTP layer the canvas providers share.
///
/// None of these hosts are ours, so every failure is a miss rather than an
/// error the player has to explain. Requests are bounded so a slow catalogue
/// cannot hold up a track change.
class CanvasHttp {
  CanvasHttp._();

  static const String userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  static const Duration _defaultTimeout = Duration(seconds: 6);

  static Future<String?> getText(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': userAgent, ...?headers})
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        developer.log(
          'canvas http ${response.statusCode} for $uri',
          name: 'CanvasHttp',
        );
        return null;
      }
      return response.body;
    } catch (error) {
      developer.log('canvas http failed for $uri: $error', name: 'CanvasHttp');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getJson(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = _defaultTimeout,
  }) async {
    final body = await getText(uri, headers: headers, timeout: timeout);
    if (body == null || body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> getBytes(
    Uri uri, {
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 12),
    int maxBytes = 12 * 1024 * 1024,
  }) async {
    try {
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = userAgent;
      if (headers != null) request.headers.addAll(headers);
      final streamed = await request.send().timeout(timeout);
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in streamed.stream.timeout(timeout)) {
        builder.add(chunk);
        if (builder.length > maxBytes) return null;
      }
      return builder.takeBytes();
    } catch (error) {
      developer.log(
        'canvas download failed for $uri: $error',
        name: 'CanvasHttp',
      );
      return null;
    }
  }
}
