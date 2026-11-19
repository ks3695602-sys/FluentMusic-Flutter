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

import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/youtube/po_token_service.dart';
import 'package:musify/services/youtube/stream_diagnostics.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// BitChord's `IOS_RECENT` identity.
///
/// YouTube sometimes accepts one iOS build and refuses another, so the newer
/// build is kept as its own rung instead of replacing [YoutubeApiClient.ios].
final _iosRecent = YoutubeApiClient(
  {
    'context': {
      'client': {
        'clientName': 'IOS',
        'clientVersion': '21.29.1',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent':
            'com.google.ios.youtube/21.29.1 (iPhone16,2; U; CPU iOS 18_5 like Mac OS X;)',
        'hl': 'en',
        'platform': 'MOBILE',
        'osName': 'IOS',
        'osVersion': '18.5.0.22F76',
        'timeZone': 'UTC',
        'gl': 'US',
        'utcOffsetMinutes': 0,
      },
    },
  },
  'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
);

/// The `WEB_REMIX` identity BitChord and Mornye both keep for
/// `music.youtube.com`.
///
/// It is last in the ladder because anonymous WEB_REMIX playback often needs
/// a PO token; it is still worth asking once every native client has refused.
final _webRemix = YoutubeApiClient(
  {
    'context': {
      'client': {
        'clientName': 'WEB_REMIX',
        'clientVersion': '1.20260707.12.00',
        'userAgent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36',
        'hl': 'en',
        'gl': 'US',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  },
  'https://music.youtube.com/youtubei/v1/player?prettyPrint=false',
);

/// The player identities tried for a stream, in order.
///
/// The order follows what BitChord's resolver measured from a browser-shaped
/// request: the tokenless VISIONOS identity first, then the native app
/// identities, then the BotGuard (`WebPO`) web clients with a freshly minted
/// PO token, then the embedded/TV fallbacks, and only then the deprecated
/// clients. WEB_REMIX closes the anonymous part of the ladder because it is
/// the identity `music.youtube.com` itself uses.
///
/// A client that mints an unplayable URL is benched for that track for ten
/// minutes, so a retry does not ask the same refused identity again.
final fallbackClients = <YoutubeApiClient>[
  YoutubeApiClient.visionOs,
  _iosRecent,
  YoutubeApiClient.ios,
  YoutubeApiClient.android,
  // BotGuard clients: they get a visitor-bound token for the player request
  // and a video-bound token for the `pot` parameter (see `_withPoTokens`).
  YoutubeApiClient.mweb,
  YoutubeApiClient.safari,
  _webRemix,
  YoutubeApiClient.tvDowngraded,
  YoutubeApiClient.webEmbedded,
  YoutubeApiClient.tv,
  YoutubeApiClient.mediaConnect,
  // ignore: deprecated_member_use
  YoutubeApiClient.androidMusic,
  // ignore: deprecated_member_use
  YoutubeApiClient.androidVr,
];

/// Per-client ceiling. A healthy player response lands in well under a second;
/// letting one stuck client eat the whole budget is what turns a fallback into
/// a timeout.
const _perClientTimeout = Duration(seconds: 5);

/// The probe only needs to prove that the CDN will send bytes.
const _probeTimeout = Duration(seconds: 5);
const _probeBytes = 16 * 1024;

/// How long a web rung may wait for BotGuard before asking the client anyway.
const _tokenBudget = Duration(seconds: 9);

/// Where googlevideo stops authorising some clients' URLs.
///
/// A URL can answer byte 0 happily and then 403 everything past this point.
/// Probing only the first kilobytes therefore reports "playable" for a stream
/// that dies a minute into the track.
const _authBoundaryBytes = 1024 * 1024;

const _refusalTtl = Duration(minutes: 10);
const _maxRefusedSongs = 64;

// Client that produced the stream URL of each song, so playback can send
// the matching headers.
final Map<String, YoutubeApiClient> _songClients = {};

/// The client that last produced a playable manifest, tried first next time.
String? _lastGoodClientKey;

/// Clients that minted an unplayable URL for a song, keyed by song id.
final Map<String, Map<String, DateTime>> _refusedClients = {};

/// A short-lived HTTP client for the pre-playback probe. It is intentionally
/// separate from the YouTube client so a probe can be cancelled without
/// disturbing the extractor's connection pool.
final http.Client _probeClient = http.Client();

/// Stable identity for a client, used by the last-good/refusal maps.
String _clientKey(YoutubeApiClient client) {
  final context = client.payload['context'];
  final clientContext = context is Map ? context['client'] : null;
  final name = clientContext is Map ? clientContext['clientName'] : null;
  final version = clientContext is Map ? clientContext['clientVersion'] : null;
  return '${name ?? 'UNKNOWN'}@${version ?? '?'}';
}

/// TV/web identities need the watch page for signature deciphering; native
/// app identities hand back plain URLs and skip that extra request.
bool _needsWatchPage(YoutubeApiClient client) {
  final key = _clientKey(client);
  return key.startsWith('TVHTML5') ||
      key.startsWith('WEB') ||
      key.startsWith('MWEB');
}

bool _isRefused(String songId, String key) {
  final entry = _refusedClients[songId];
  if (entry == null) return false;
  final until = entry[key];
  if (until == null) return false;
  if (DateTime.now().isAfter(until)) {
    entry.remove(key);
    return false;
  }
  return true;
}

void _markRefused(String songId, String key) {
  if (_refusedClients.length >= _maxRefusedSongs) {
    _refusedClients.remove(_refusedClients.keys.first);
  }
  _refusedClients.putIfAbsent(songId, () => <String, DateTime>{})[key] =
      DateTime.now().add(_refusalTtl);
}

/// Last-good client first, then the documented ladder, minus identities that
/// already refused this track.
List<YoutubeApiClient> _orderedClients(String songId) {
  final lastGood = _lastGoodClientKey;
  final ordered = <YoutubeApiClient>[];

  if (lastGood != null) {
    for (final client in fallbackClients) {
      if (_clientKey(client) == lastGood) {
        ordered.add(client);
        break;
      }
    }
  }

  for (final client in fallbackClients) {
    if (_clientKey(client) == lastGood) continue;
    if (_isRefused(songId, _clientKey(client))) continue;
    ordered.add(client);
  }

  return ordered;
}

/// Picks the highest-bitrate audio stream for the probe.
AudioOnlyStreamInfo _bestAudio(StreamManifest manifest) {
  var best = manifest.audioOnly.first;
  for (final stream in manifest.audioOnly) {
    if (stream.bitrate.compareTo(best.bitrate) > 0) best = stream;
  }
  return best;
}

/// Proves a minted audio URL actually authorises bytes.
///
/// A URL can be well-formed and still 403, answer headers and then stall, or —
/// the failure this probe exists for — serve the first megabyte and refuse
/// everything after it. Reading from [_authBoundaryBytes] when the file is
/// long enough catches that last case before playback starts.
///
/// Returns the offset that answered, or null when the URL refused.
Future<int?> _probeAudio(
  AudioOnlyStreamInfo stream,
  YoutubeApiClient client, {
  required Duration timeout,
}) async {
  final length = stream.size.totalBytes;
  final start =
      length > _authBoundaryBytes + _probeBytes ? _authBoundaryBytes : 0;

  http.StreamedResponse? response;
  try {
    final request = http.Request('GET', stream.url)
      ..headers.addAll(clientRequestHeaders(client))
      ..headers['Range'] = 'bytes=$start-${start + _probeBytes - 1}';
    response = await _probeClient.send(request).timeout(timeout);

    final status = response.statusCode;
    if (status == 403 || status == 404 || status == 410) {
      return null;
    }
    if (status < 200 || status >= 300) return null;

    final contentType = (response.headers['content-type'] ?? '').toLowerCase();
    if (contentType.contains('text/html') ||
        contentType.contains('application/json')) {
      return null;
    }

    final chunk = await response.stream.first.timeout(timeout);
    return chunk.isEmpty ? null : start;
  } catch (error) {
    developer.log(
      'Probe failed for ${_clientKey(client)} at $start: $error',
      name: 'StreamClients',
    );
    return null;
  } finally {
    // Drop the rest of the range without downloading it.
    try {
      await response?.stream.listen(null).cancel();
    } catch (_) {
      // The stream may already be closed; nothing to do.
    }
  }
}

/// The web clients need BotGuard tokens; every other identity ignores them.
///
/// Token minting is bounded: the page runs on a headless WebView, and waiting
/// on it must never eat the whole streaming budget. Without tokens the rung is
/// still tried, and the boundary probe decides honestly whether it plays.
Future<YoutubeApiClient> _withPoTokens(
  YoutubeApiClient client,
  String songId,
) async {
  if (!client.isWebPoClient) return client;
  if (!webPoTokensEnabled.value) return client;

  final tokens = await PoTokenService.instance
      .tokensFor(songId)
      .timeout(_tokenBudget, onTimeout: () => null);
  if (tokens == null) return client;

  return client.withPoToken(
    poToken: tokens.playerRequestToken,
    streamingPoToken: tokens.streamingToken,
    visitorData: tokens.visitorData,
  );
}

/// Fetches a stream manifest through the full client ladder.
///
/// [timeout] is the total budget, not a per-client one. [verifyAudio] is off
/// for proxy validation: the probe uses the direct network, so it would
/// incorrectly reject a manifest that only the proxy can reach.
Future<StreamManifest> getManifestWithFallback(
  YoutubeExplode yt,
  String songId, {
  required Duration timeout,
  bool verifyAudio = true,
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  StackTrace? lastStack;
  final clients = _orderedClients(songId);

  for (final baseClient in clients) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= const Duration(milliseconds: 500)) break;

    final perClient =
        remaining < _perClientTimeout ? remaining : _perClientTimeout;
    final key = _clientKey(baseClient);
    final started = DateTime.now();

    try {
      final client = await _withPoTokens(baseClient, songId);

      final manifest = await yt.videos.streams
          .getManifest(
            songId,
            ytClients: [client],
            requireWatchPage: _needsWatchPage(client),
          )
          .timeout(perClient);

      if (manifest.audioOnly.isEmpty) {
        throw VideoUnavailableException('No audio streams for "$songId"');
      }

      var probeOffset = 0;
      if (verifyAudio) {
        final probed = await _probeAudio(
          _bestAudio(manifest),
          client,
          timeout: _probeTimeout,
        );
        if (probed == null) {
          _markRefused(songId, key);
          throw VideoUnavailableException(
            'Client $key minted an audio URL that refused the boundary probe '
            'for "$songId"',
          );
        }
        probeOffset = probed;
      }

      _songClients[songId] = client;
      _lastGoodClientKey = key;
      recordStreamAttempt(
        StreamAttempt(
          songId: songId,
          client: key,
          ok: true,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
          usedTokens: client.poToken != null,
          probeBytes: probeOffset,
        ),
      );
      return manifest;
    } catch (error, stackTrace) {
      developer.log(
        'Client $key failed for $songId: $error',
        name: 'StreamClients',
      );
      recordStreamAttempt(
        StreamAttempt(
          songId: songId,
          client: key,
          ok: false,
          latencyMs: DateTime.now().difference(started).inMilliseconds,
          reason: '$error',
          usedTokens: baseClient.isWebPoClient && webPoTokensEnabled.value,
        ),
      );
      lastError = error;
      lastStack = stackTrace;
    }
  }

  if (lastError != null) {
    Error.throwWithStackTrace(lastError!, lastStack!);
  }
  throw VideoUnavailableException(
    'No playable audio streams for "$songId" after trying '
    '${clients.length} clients',
  );
}

/// Headers googlevideo.com expects for URLs minted by the client that served
/// [songId]; a mismatched User-Agent can cause HTTP 403.
Map<String, String> streamPlaybackHeaders(String? songId) {
  final client = _songClients[songId] ?? fallbackClients.first;
  return clientRequestHeaders(client);
}
