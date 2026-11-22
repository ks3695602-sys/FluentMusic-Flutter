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

/// How long a track every identity refused is remembered as unplayable.
///
/// Without this, a queue that hits one dead row retries the whole client
/// ladder for it on every preload tick and every playback attempt, which is
/// how a single unavailable song turns into a retry storm that starves the
/// track that is actually playing.
const _unplayableTtl = Duration(minutes: 10);
const _maxUnplayableSongs = 32;

// Client that produced the stream URL of each song, so playback can send
// the matching headers.
final Map<String, YoutubeApiClient> _songClients = {};

/// Tracks every client refused, with the time the verdict expires.
final Map<String, DateTime> _unplayableUntil = {};

/// Whether [songId] was refused by every client recently enough that asking
/// again would only repeat the same refusals.
bool isSongMarkedUnplayable(String songId) {
  final until = _unplayableUntil[songId];
  if (until == null) return false;
  if (DateTime.now().isAfter(until)) {
    _unplayableUntil.remove(songId);
    return false;
  }
  return true;
}

/// Forgets a track's unplayable verdict, e.g. after its URL was invalidated.
void clearUnplayableVerdict(String songId) => _unplayableUntil.remove(songId);

void _markUnplayable(String songId) {
  if (_unplayableUntil.length >= _maxUnplayableSongs) {
    _unplayableUntil.remove(_unplayableUntil.keys.first);
  }
  _unplayableUntil[songId] = DateTime.now().add(_unplayableTtl);
}

/// A refusal that a retry cannot fix: the track is gone, region-locked or
/// every identity was answered with 403/410. Timeouts and socket errors are
/// deliberately excluded — those are worth retrying once the network recovers.
bool _isDefinitiveRefusal(Object? error) {
  final text = error?.toString().toLowerCase() ?? '';
  if (text.isEmpty) return false;
  return text.contains('unavailable') ||
      text.contains('not available') ||
      text.contains('refused') ||
      text.contains('403') ||
      text.contains('410');
}

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
///
/// The last-good identity is not exempt from the refusal list: a client that
/// played the previous track can still be the one that refused this one, and
/// trying it first would only waste the per-client budget.
List<YoutubeApiClient> _orderedClients(String songId) {
  final lastGood = _lastGoodClientKey;
  final ordered = <YoutubeApiClient>[];

  if (lastGood != null && !_isRefused(songId, lastGood)) {
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
      ..headers.addAll(_mediaHeaders(client))
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
  if (isSongMarkedUnplayable(songId)) {
    throw VideoUnavailableException(
      'Every client refused "$songId" recently; not retrying yet',
    );
  }

  final startedAt = DateTime.now();
  final deadline = startedAt.add(timeout);
  Object? lastError;
  StackTrace? lastStack;
  final clients = _orderedClients(songId);
  var rung = 0;

  for (final baseClient in clients) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= const Duration(milliseconds: 500)) break;

    final perClient =
        remaining < _perClientTimeout ? remaining : _perClientTimeout;
    final key = _clientKey(baseClient);
    final started = DateTime.now();
    // The first rung is the fast path. Gyawun's plan named ANDROID_VR for it,
    // but the vendored extractor documents that YouTube 403'd every ANDROID_VR
    // format on 2026-08-17 (yt-dlp dropped it from its defaults), so the fast
    // path is whichever tokenless identity the ladder rates first today.
    // ANDROID_VR is still kept as the last rung for the occasional window
    // where YouTube accepts it again.
    final path = rung++ == 0 ? 'primary' : 'fallback';
    developer.log(
      'stream timing: $path $key for $songId',
      name: 'StreamClients',
    );

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
      _unplayableUntil.remove(songId);
      developer.log(
        'stream timing: $path $key ok for $songId in '
        '${DateTime.now().difference(started).inMilliseconds}ms',
        name: 'StreamClients',
      );
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
      developer.log(
        'stream timing: $path $key failed for $songId in '
        '${DateTime.now().difference(started).inMilliseconds}ms: $error',
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
    developer.log(
      'stream timing: ladder exhausted for $songId after '
      '${DateTime.now().difference(startedAt).inMilliseconds}ms',
      name: 'StreamClients',
    );
    if (_isDefinitiveRefusal(lastError)) _markUnplayable(songId);
    Error.throwWithStackTrace(lastError, lastStack!);
  }
  developer.log(
    'stream timing: ladder exhausted for $songId (no client left)',
    name: 'StreamClients',
  );
  _markUnplayable(songId);
  throw VideoUnavailableException(
    'No playable audio streams for "$songId" after trying '
    '${clients.length} clients',
  );
}

/// Headers googlevideo.com expects for URLs minted by the client that served
/// [songId]; a mismatched User-Agent can cause HTTP 403.
///
/// Prefer [streamPlaybackHeadersForUrl] wherever the URL is in hand: after an
/// app restart the in-memory client map is empty, and the URL itself is the
/// only record of which identity minted it.
Map<String, String> streamPlaybackHeaders(String? songId) {
  final client = _songClients[songId] ?? fallbackClients.first;
  return _mediaHeaders(client);
}

/// Headers a media fetch for [url] must carry.
///
/// googlevideo bakes the minting client into the URL as `c=`/`cver=` and
/// compares those against the request that comes back for the bytes. Sending
/// the wrong identity is answered with a 403 or a response paced down to a
/// crawl, which is exactly the stutter this avoids. When the URL names an
/// identity the app does not model, an iPhone identity is the safest guess
/// (BitChord's `PlayerClient.forStreamUrl` makes the same choice).
Map<String, String> streamPlaybackHeadersForUrl(String? songId, String? url) {
  final minted = songId == null ? null : _songClients[songId];
  if (minted != null) return _mediaHeaders(minted);

  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.host.endsWith('googlevideo.com')) {
    return _mediaHeaders(fallbackClients.first);
  }

  final name = (uri.queryParameters['c'] ?? '').toUpperCase();
  final version = uri.queryParameters['cver'];
  if (name.isEmpty) return _mediaHeaders(fallbackClients.first);

  return _headersForNamedClient(name, version);
}

/// Media headers for the identity a googlevideo URL names in `c`/`cver`.
Map<String, String> _headersForNamedClient(String name, String? version) {
  if (name.startsWith('IOS')) {
    final ios = version == _clientVersion(_iosRecent)
        ? _iosRecent
        : YoutubeApiClient.ios;
    return _mediaHeaders(ios);
  }
  if (name == 'ANDROID_VR') {
    // ignore: deprecated_member_use
    return _mediaHeaders(YoutubeApiClient.androidVr);
  }
  if (name == 'ANDROID_MUSIC') {
    // ignore: deprecated_member_use
    return _mediaHeaders(YoutubeApiClient.androidMusic);
  }
  if (name.startsWith('ANDROID')) {
    return _mediaHeaders(YoutubeApiClient.android);
  }
  if (name.startsWith('TVHTML5_SIMPLY')) {
    return _mediaHeaders(YoutubeApiClient.tvDowngraded);
  }
  if (name.startsWith('TVHTML5')) {
    return _mediaHeaders(YoutubeApiClient.tv);
  }
  if (name == 'MEDIA_CONNECT_FRONTEND') {
    return _mediaHeaders(YoutubeApiClient.mediaConnect);
  }
  if (name == 'WEB_REMIX') {
    return _mediaHeaders(_webRemix);
  }
  if (name.startsWith('WEB') || name == 'MWEB') {
    // The ladder has no plain WEB identity; WEB_REMIX carries the same
    // desktop Chrome agent and only the origin differs.
    return _mediaHeaders(_webRemix, origin: 'https://www.youtube.com');
  }
  if (name == 'VISIONOS') {
    return _mediaHeaders(YoutubeApiClient.visionOs);
  }
  return _mediaHeaders(YoutubeApiClient.ios);
}

String _clientVersion(YoutubeApiClient client) {
  final context = client.payload['context'];
  final clientContext = context is Map ? context['client'] : null;
  final version = clientContext is Map ? clientContext['clientVersion'] : null;
  return version is String ? version : '';
}

/// The client's own request headers, plus the origin a browser-shaped client
/// is expected to send.
///
/// Native app identities send no origin, and sending one anyway is as wrong as
/// omitting it from a web client. `Origin`/`Referer` also make the `WEB` and
/// `TVHTML5` families behave like their real counterparts.
Map<String, String> _mediaHeaders(
  YoutubeApiClient client, {
  String? origin,
}) {
  final headers = clientRequestHeaders(client);
  final name = client.clientName;

  final effectiveOrigin = origin ??
      (name == 'WEB_REMIX'
          ? 'https://music.youtube.com'
          : (name.startsWith('WEB') ||
                  name == 'MWEB' ||
                  name.startsWith('TVHTML5'))
              ? 'https://www.youtube.com'
              : null);
  if (effectiveOrigin != null) {
    headers['origin'] = effectiveOrigin;
    headers['referer'] = '$effectiveOrigin/';
  }
  return headers;
}
