/*
 *     Copyright (C) 2026 Valeri Gokadze
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
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musify/services/logger_service.dart';
import 'package:musify/services/settings_manager.dart';

/// The Cobalt bridge used by Mornye's YouTube Music extension.
///
/// This is deliberately the very last resort: every InnerTube client is asked
/// first, and this is only reached when all of them refused the track. Only the
/// public video id leaves the device — no cookie, account or library data.
const _cobaltEndpoint = 'https://api.zarz.moe/v1/dl/cobalt';

/// Resolves a short-lived direct audio URL through the Cobalt bridge.
///
/// Returns null when the switch is off, the request fails, or the response has
/// no playable URL. The caller caches the URL exactly like an InnerTube one;
/// because its host is not `googlevideo.com`, playback sends no YouTube
/// client headers with it.
Future<String?> resolveRemoteAudioUrl(String videoId) async {
  if (!remoteStreamFallbackEnabled.value || videoId.isEmpty) return null;

  try {
    final response = await http
        .post(
          Uri.parse(_cobaltEndpoint),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'FluentMusic/1.5.3',
          },
          body: jsonEncode({
            'url': 'https://www.youtube.com/watch?v=$videoId',
            'downloadMode': 'audio',
            'audioFormat': 'best',
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      logger.log(
        'Remote stream fallback returned HTTP ${response.statusCode} '
        'for $videoId',
      );
      return null;
    }

    final payload = jsonDecode(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    final url = _extractAudioUrl(payload);
    if (url == null) {
      logger.log('Remote stream fallback had no audio URL for $videoId');
      return null;
    }

    logger.log('Remote stream fallback resolved $videoId');
    return url;
  } catch (e, stackTrace) {
    logger.log(
      'Remote stream fallback failed for $videoId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Accepts the response shapes Cobalt and its bridges use.
String? _extractAudioUrl(dynamic payload) {
  if (payload is! Map) return null;

  for (final key in const [
    'url',
    'audio',
    'audioUrl',
    'downloadUrl',
    'download_url',
  ]) {
    final value = payload[key];
    if (value is String && value.startsWith('http')) return value;
  }

  final picker = payload['picker'];
  if (picker is List) {
    for (final item in picker) {
      final url = _extractAudioUrl(item);
      if (url != null) return url;
    }
  }

  return _extractAudioUrl(payload['data']);
}
