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
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/lyrics/ttml_parser.dart';

/// Fetches word-synced TTML lyrics from the open Binimum API.
///
/// **Source:** <https://lyrics-api.binimum.org/>
/// **Access:** Public API; no key is required. Requests are bounded by an
/// eight-second timeout and the app's normal in-memory lyrics cache.
/// **Credit:** Results are labelled "Binimum Lyrics" in the player UI.
///
/// The lookup searches by title + artist (optionally album + duration),
/// then ranks results: word-timed entries first, then closest duration match.
/// The best match's TTML URL is fetched and parsed into [LyricLine]s.
Future<Lyrics?> fetchFromBinimum(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;
  final deadline = DateTime.now().add(timeout);

  try {
    // 1. Search for matching tracks
    final searchUri = Uri.https('lyrics-api.binimum.org', '/', {
      'track': title,
      'artist': artist,
      if (track.album != null && track.album!.trim().isNotEmpty)
        'album': track.album!.trim(),
      if (track.duration != null && track.duration!.inSeconds > 0)
        'duration': track.duration!.inSeconds.toString(),
    });

    final searchResponse = await _getFollowingRedirects(
      httpClient,
      searchUri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'FluentMusic (https://github.com/ks3695602-sys/FluentMusic-Flutter)',
      },
      timeout: _remainingTimeout(deadline, timeout),
    );

    if (searchResponse.statusCode != 200) return null;

    final body = utf8
        .decode(searchResponse.bodyBytes, allowMalformed: true)
        .trim();
    if (body.isEmpty) return null;

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return null;
    final results = json['results'];
    if (results is! List || results.isEmpty) return null;

    // 2. Pick best match: word-timed wins, then closest duration
    final matches = <_TrackMatch>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final lyricsUrl = raw['lyricsUrl'];
      if (lyricsUrl is! String || lyricsUrl.trim().isEmpty) continue;

      matches.add(
        _TrackMatch(
          lyricsUrl: lyricsUrl.trim(),
          timingType: raw['timing_type'] is String
              ? (raw['timing_type'] as String).trim().toLowerCase()
              : null,
          duration: raw['duration'] is num
              ? (raw['duration'] as num).toDouble()
              : null,
        ),
      );
    }
    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final aIsWord = a.timingType == 'word' ? 0 : 1;
      final bIsWord = b.timingType == 'word' ? 0 : 1;
      if (aIsWord != bIsWord) return aIsWord.compareTo(bIsWord);

      final targetSecs = track.duration?.inSeconds ?? 0;
      if (targetSecs > 0) {
        final aDistance = a.duration == null
            ? double.infinity
            : (a.duration! - targetSecs).abs();
        final bDistance = b.duration == null
            ? double.infinity
            : (b.duration! - targetSecs).abs();
        final durationOrder = aDistance.compareTo(bDistance);
        if (durationOrder != 0) return durationOrder;
      }
      return 0;
    });

    final best = matches.first;

    // 3. Fetch TTML from the matched URL
    final ttmlUri = Uri.tryParse(best.lyricsUrl);
    if (ttmlUri == null || ttmlUri.scheme != 'https' || ttmlUri.host.isEmpty) {
      return null;
    }

    final ttmlResponse = await _getFollowingRedirects(
      httpClient,
      ttmlUri,
      headers: {
        'Accept': 'application/ttml+xml, application/xml, text/xml',
        'User-Agent': 'FluentMusic (https://github.com/ks3695602-sys/FluentMusic-Flutter)',
      },
      timeout: _remainingTimeout(deadline, timeout),
    );

    if (ttmlResponse.statusCode != 200) return null;

    final ttml = utf8
        .decode(ttmlResponse.bodyBytes, allowMalformed: true)
        .trim();
    if (ttml.isEmpty || !ttml.startsWith('<tt')) return null;

    final lines = parseTtml(ttml);
    if (lines.isEmpty) return null;

    return Lyrics(
      source: 'Binimum Lyrics',
      plain: lines.map((l) => l.text).join('\n'),
      synced: lines,
    );
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

Duration _remainingTimeout(DateTime deadline, Duration fallback) {
  final remaining = deadline.difference(DateTime.now());
  if (remaining <= Duration.zero)
    throw TimeoutException('Binimum request timed out');
  return remaining < fallback ? remaining : fallback;
}

Future<http.Response> _getFollowingRedirects(
  http.Client client,
  Uri uri, {
  required Map<String, String> headers,
  required Duration timeout,
}) async {
  var current = uri;
  final deadline = DateTime.now().add(timeout);
  for (var redirects = 0; redirects <= 5; redirects++) {
    final response = await client
        .get(current, headers: headers)
        .timeout(_remainingTimeout(deadline, timeout));

    if (response.statusCode < 300 || response.statusCode >= 400) {
      return response;
    }

    final location = response.headers['location'];
    if (location == null || location.trim().isEmpty) return response;
    final next = current.resolve(location);
    if (next.scheme != 'https' || next.host.isEmpty) return response;
    current = next;
  }
  throw const FormatException('Binimum exceeded the redirect limit');
}

class _TrackMatch {
  const _TrackMatch({required this.lyricsUrl, this.timingType, this.duration});

  final String lyricsUrl;
  final String? timingType;
  final double? duration;
}
