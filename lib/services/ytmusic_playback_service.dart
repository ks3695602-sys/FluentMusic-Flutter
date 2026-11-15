/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/foundation.dart';
import 'package:musify/services/innertube_client.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/ytmusic_auth_service.dart';

/// Experimental, opt-in account-bound stream resolution.
///
/// **This never replaces the anonymous path.** [tryResolveStreamUrl] returns
/// `null` unless *all* of these are true:
///   1. the user enabled [ytMusicSignedInPlayback],
///   2. a YouTube Music session is connected,
///   3. the `player` response contains a plain (non-cipher) audio URL.
///
/// YouTube currently requires a `poToken` for most signed-in audio formats, so
/// in practice condition 3 usually fails and playback continues through
/// `youtube_explode` exactly as before. That is intentional: the fallback is
/// the default, not an error path.
class YtMusicPlaybackService {
  YtMusicPlaybackService({InnerTubeClient? client, YtMusicAuthService? authService})
    : _client = client ?? InnerTubeClient(),
      _authService = authService ?? ytMusicAuthService;

  final InnerTubeClient _client;
  final YtMusicAuthService _authService;

  /// True when the experimental path is enabled *and* usable right now.
  bool get isAvailable => ytMusicSignedInPlayback.value && _authService.isConnected;

  /// Resolves a signed-in audio URL, or `null` to let the caller fall back.
  ///
  /// Deliberately swallows every failure: the anonymous resolver is the
  /// source of truth for playback, and this is only an opportunistic upgrade.
  Future<String?> tryResolveStreamUrl(String videoId) async {
    if (!isAvailable || videoId.isEmpty) return null;

    final auth = _authService.auth;
    try {
      final response = await _client.post(
        'player',
        <String, dynamic>{
          'context': _client.buildContext(auth),
          'videoId': videoId,
          'playbackContext': {
            'contentPlaybackContext': {
              'html5Preference': 'HTML5_PREF_WANTS',
              'signatureTimestamp': 0,
            },
          },
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        auth: auth,
        authenticated: true,
      );

      final streamingData = response['streamingData'];
      if (streamingData is! Map) return null;
      final formats = streamingData['adaptiveFormats'];
      if (formats is! List || formats.isEmpty) return null;

      final candidates = <_AudioCandidate>[];
      for (final raw in formats) {
        if (raw is! Map) continue;
        final mime = raw['mimeType']?.toString() ?? '';
        if (!mime.startsWith('audio/')) continue;
        final url = raw['url']?.toString();
        // Cipher-only entries are skipped on purpose: deciphering needs the
        // player JS, which is out of scope for this opt-in experiment.
        if (url == null || url.isEmpty) continue;
        final bitrate = (raw['bitrate'] as num?)?.toInt() ?? 0;
        candidates.add(_AudioCandidate(url: url, bitrate: bitrate));
      }
      if (candidates.isEmpty) return null;

      candidates.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return _pickForQuality(candidates).url;
    } catch (error) {
      // Expected on most accounts (poToken / bot guard). Keep it quiet.
      debugPrint('YtMusicPlaybackService: falling back (${error.runtimeType})');
      return null;
    }
  }

  _AudioCandidate _pickForQuality(List<_AudioCandidate> sorted) {
    switch (audioQualitySetting.value) {
      case 'low':
        return sorted.last;
      case 'medium':
        return sorted[(sorted.length - 1) ~/ 2];
      default:
        return sorted.first;
    }
  }
}

class _AudioCandidate {
  const _AudioCandidate({required this.url, required this.bitrate});

  final String url;
  final int bitrate;
}

/// Shared instance used by the stream resolver.
final YtMusicPlaybackService ytMusicPlaybackService = YtMusicPlaybackService();
