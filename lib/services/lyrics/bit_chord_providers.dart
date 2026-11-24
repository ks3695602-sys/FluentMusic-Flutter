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
 *     Lyrics provider request/response handling is a Dart port of the
 *     ArchiveTune (BitChord) lyrics modules, GPL-3.0:
 *     https://github.com/kushagrasinghx/BitChord
 *     https://github.com/rukamori/lyrics
 */

import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:musify/services/lyrics/lrc_parser.dart';
import 'package:musify/services/lyrics/lyrics_models.dart';
import 'package:musify/services/lyrics/lyrics_settings.dart';
import 'package:musify/services/lyrics/ttml_parser.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

const _userAgent =
    'FluentMusic (https://github.com/ks3695602-sys/FluentMusic-Flutter)';
const _defaultTimeout = Duration(seconds: 7);

final _timedLinePattern = RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]');
final _ttmlRootPattern = RegExp(r'<(?:[A-Za-z_][\w.-]*:)?tt(?:\s|>)');

Map<String, String> _headers([Map<String, String>? extra]) => {
  'User-Agent': _userAgent,
  'Accept': 'application/json, text/plain, */*',
  ...?extra,
};

Future<http.Response> _get(
  http.Client client,
  Uri uri, {
  Map<String, String>? headers,
  Duration timeout = _defaultTimeout,
}) => client.get(uri, headers: _headers(headers)).timeout(timeout);

Future<http.Response> _postJson(
  http.Client client,
  Uri uri,
  Object body, {
  Map<String, String>? headers,
  Duration timeout = _defaultTimeout,
}) => client
    .post(
      uri,
      headers: _headers({'Content-Type': 'application/json', ...?headers}),
      body: jsonEncode(body),
    )
    .timeout(timeout);

dynamic _decodeJson(String body) {
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

bool _looksLikeLyricsText(String text) =>
    _ttmlRootPattern.hasMatch(text) || _timedLinePattern.hasMatch(text);

String? _findLyricsString(Object? value, {int depth = 0}) {
  if (depth > 4) return null;

  if (value is String) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (_looksLikeLyricsText(text)) return text;
    if (depth < 3 && (text.startsWith('{') || text.startsWith('['))) {
      final nested = _decodeJson(text);
      if (nested != null) {
        return _findLyricsString(nested, depth: depth + 1);
      }
    }
    return null;
  }

  if (value is List) {
    for (final item in value) {
      final found = _findLyricsString(item, depth: depth + 1);
      if (found != null) return found;
    }
    return null;
  }

  if (value is Map) {
    for (final key in const [
      'ttml',
      'lyrics',
      'lrc',
      'syncedLyrics',
      'plainLyrics',
      'content',
      'data',
      'result',
      'response',
    ]) {
      if (!value.containsKey(key)) continue;
      final found = _findLyricsString(value[key], depth: depth + 1);
      if (found != null) return found;
    }
    for (final item in value.values) {
      final found = _findLyricsString(item, depth: depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

String? _findPlainLyrics(Object? value, {int depth = 0}) {
  if (depth > 4) return null;
  if (value is String) {
    final text = value.trim();
    if (text.isEmpty || text.startsWith('{') || text.startsWith('[')) {
      return null;
    }
    return text;
  }
  if (value is List) {
    for (final item in value) {
      final found = _findPlainLyrics(item, depth: depth + 1);
      if (found != null) return found;
    }
    return null;
  }
  if (value is Map) {
    for (final key in const [
      'lyrics',
      'lrc',
      'content',
      'plainLyrics',
      'syncedLyrics',
      'text',
      'line',
      'lyric',
    ]) {
      if (!value.containsKey(key)) continue;
      final found = _findPlainLyrics(value[key], depth: depth + 1);
      if (found != null) return found;
    }
  }
  return null;
}

/// Builds a [Lyrics] value from a provider response that can be TTML, LRC or
/// plain text. A non-TTML XML document is rejected instead of being shown as
/// lyrics.
Lyrics? lyricsFromRaw(String raw, String source) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  List<LyricLine>? synced;
  if (_ttmlRootPattern.hasMatch(trimmed)) {
    final lines = parseTtml(trimmed);
    if (lines.isEmpty) return null;
    synced = lines;
  } else if (_timedLinePattern.hasMatch(trimmed)) {
    final lines = parseLrc(trimmed);
    if (lines.isNotEmpty) synced = lines;
  } else if (trimmed.startsWith('<')) {
    return null;
  }

  final plain = synced != null
      ? synced.map((line) => line.text).join('\n')
      : trimmed;
  final lyrics = Lyrics(source: source, plain: plain, synced: synced);
  return lyrics.isEmpty ? null : lyrics;
}

// --------------------------------------------------------------- BetterLyrics

Future<Lyrics?> fetchBetterLyrics(
  TrackInfo track, {
  http.Client? client,
  bool portato = false,
  Duration timeout = _defaultTimeout,
}) async {
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;
  final source = portato ? 'BetterLyrics Portato' : 'BetterLyrics';

  try {
    final query = <String, String>{
      's': title,
      'a': artist,
      if (track.album != null && track.album!.trim().isNotEmpty)
        'al': track.album!.trim(),
      if (track.duration != null && track.duration!.inSeconds > 0)
        'd': track.duration!.inSeconds.toString(),
    };

    final endpoints = portato
        ? const ['/qq/getLyrics']
        : const ['/getLyrics', '/kugou/getLyrics'];
    for (final endpoint in endpoints) {
      final response = await _get(
        httpClient,
        Uri.https('lyrics-api.boidu.dev', endpoint, query),
        timeout: timeout,
      );
      if (response.statusCode != 200) continue;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      final decoded = _decodeJson(body);
      final payload = decoded == null ? body : _findLyricsString(decoded);
      if (payload == null) continue;
      final lyrics = lyricsFromRaw(payload, source);
      if (lyrics != null) return lyrics;
    }

    if (!portato) {
      // Older public endpoint, kept as a fallback for tracks the new host
      // does not index.
      final response = await _get(
        httpClient,
        Uri.https('api.betterlyrics.org', '/getLyrics', query),
        timeout: timeout,
      );
      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final decoded = _decodeJson(body);
        final payload = _findLyricsString(decoded);
        if (payload != null) return lyricsFromRaw(payload, source);
        // Preserve compatibility with legacy plain-text responses, but never
        // mistake an unrelated JSON error/result envelope for lyric text.
        if (decoded == null) return lyricsFromRaw(body, source);
      }
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

// ------------------------------------------------------------------ YouLyPlus

const _youLyPlusMirrors = [
  'lyricsplus.binimum.org',
  'lyricsplus.prjktla.my.id',
  'lyricsplus.prjktla.workers.dev',
  'lyricsplus.atomix.one',
  'lyricsplus-seven.vercel.app',
];

Future<Lyrics?> fetchYouLyPlus(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;
  final query = <String, String>{
    'title': title,
    'artist': artist,
    if (track.album != null && track.album!.trim().isNotEmpty)
      'album': track.album!.trim(),
    if (track.duration != null && track.duration!.inSeconds > 0)
      'duration': track.duration!.inSeconds.toString(),
  };

  try {
    for (final mirror in _youLyPlusMirrors) {
      try {
        final ttmlResponse = await _get(
          httpClient,
          Uri.https(mirror, '/v1/ttml/get', query),
          timeout: timeout,
        );
        if (ttmlResponse.statusCode == 200) {
          final body = utf8.decode(
            ttmlResponse.bodyBytes,
            allowMalformed: true,
          );
          final decoded = _decodeJson(body);
          final payload = decoded == null ? body : _findLyricsString(decoded);
          if (payload == null) continue;
          final ttmlLyrics = lyricsFromRaw(payload, 'YouLy+');
          if (ttmlLyrics != null) return ttmlLyrics;
        }

        final linesResponse = await _get(
          httpClient,
          Uri.https(mirror, '/v2/lyrics/get', query),
          timeout: timeout,
        );
        if (linesResponse.statusCode != 200) continue;
        final body = utf8.decode(linesResponse.bodyBytes, allowMalformed: true);
        final parsed = _youLyPlusFromJson(_decodeJson(body));
        if (parsed != null) return parsed;
      } catch (_) {
        // Try the next mirror.
      }
    }
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

Lyrics? _youLyPlusFromJson(dynamic json) {
  if (json is! Map) return null;
  final rawLines = json['lyrics'];
  if (rawLines is! List) return null;

  final isWordSync = (json['type'] ?? '').toString().toLowerCase() == 'word';
  final synced = <LyricLine>[];
  final plain = <String>[];

  for (final raw in rawLines) {
    if (raw is! Map) continue;
    final text = (raw['text'] ?? '').toString().trim();
    if (text.isEmpty) continue;
    final time = raw['time'];
    if (time is! num) {
      plain.add(text);
      continue;
    }

    final start = Duration(milliseconds: time.toInt());
    final length = raw['duration'];
    Duration? end = length is num
        ? start + Duration(milliseconds: length.toInt())
        : null;

    final words = <LyricWord>[];
    if (isWordSync && raw['syllabus'] is List) {
      for (final syllable in raw['syllabus'] as List) {
        if (syllable is! Map) continue;
        final syllableText = (syllable['text'] ?? '').toString();
        final syllableTime = syllable['time'];
        if (syllableText.isEmpty || syllableTime is! num) continue;
        words.add(
          LyricWord(
            text: syllableText,
            start: Duration(milliseconds: syllableTime.toInt()),
            end: Duration(milliseconds: syllableTime.toInt()),
          ),
        );
      }
      words.sort((a, b) => a.start.compareTo(b.start));
      for (var i = 0; i < words.length; i++) {
        final wordEnd = i + 1 < words.length
            ? words[i + 1].start
            : (end ?? words[i].start + const Duration(seconds: 2));
        words[i] = LyricWord(
          text: words[i].text,
          start: words[i].start,
          end: wordEnd,
        );
      }
      end ??= words.isNotEmpty
          ? words.last.end
          : start + const Duration(seconds: 4);
    }

    synced.add(
      LyricLine(start, text, end: end, words: List.unmodifiable(words)),
    );
  }

  if (synced.isNotEmpty) {
    synced.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 0; i < synced.length; i++) {
      if (synced[i].end != null) continue;
      final nextStart = i + 1 < synced.length ? synced[i + 1].start : null;
      synced[i] = LyricLine(
        synced[i].start,
        synced[i].text,
        end: nextStart ?? synced[i].start + const Duration(seconds: 4),
        words: synced[i].words,
      );
    }
    return Lyrics(
      source: 'YouLy+',
      plain: synced.map((line) => line.text).join('\n'),
      synced: synced,
    );
  }

  if (plain.isNotEmpty) {
    return Lyrics(source: 'YouLy+', plain: plain.join('\n'));
  }
  return null;
}

// ------------------------------------------------------------------ SimpMusic

Future<Lyrics?> fetchSimpMusic(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final videoId = track.videoId?.trim();
  if (videoId == null || videoId.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;

  try {
    final response = await _get(
      httpClient,
      Uri.https('api-lyrics.simpmusic.org', '/v1/$videoId'),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'SimpMusicLyrics/1.0',
      },
      timeout: timeout,
    );
    if (response.statusCode != 200) return null;

    final json = _decodeJson(
      utf8.decode(response.bodyBytes, allowMalformed: true),
    );
    if (json is! Map || json['type'] != 'success') return null;
    final data = json['data'];
    if (data is! List) return null;

    final candidates = data.whereType<Map>().toList(growable: false);
    if (candidates.isEmpty) return null;

    Map? best = candidates.first;
    final seconds = track.duration?.inSeconds;
    if (seconds != null && seconds > 0 && candidates.length > 1) {
      var bestDistance = double.infinity;
      for (final candidate in candidates) {
        final duration = candidate['durationSeconds'];
        if (duration is! num) continue;
        final distance = (duration.toDouble() - seconds).abs();
        if (distance < bestDistance) {
          bestDistance = distance;
          best = candidate;
        }
      }
    }

    final selected = best;
    if (selected == null) return null;
    final raw =
        selected['syncedLyrics'] ??
        selected['richSyncLyrics'] ??
        selected['plainLyric'] ??
        selected['plainLyrics'];
    if (raw is! String) return null;
    return lyricsFromRaw(raw, 'SimpMusic');
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

// --------------------------------------------------------------------- KuGou

Future<Lyrics?> fetchKuGou(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;
  final keyword = '$title - $artist';
  final targetSeconds = track.duration?.inSeconds;

  try {
    final songsResponse = await _get(
      httpClient,
      Uri.https('mobileservice.kugou.com', '/api/v3/search/song', {
        'version': '9108',
        'plat': '0',
        'pagesize': '8',
        'showtype': '0',
        'keyword': keyword,
      }),
      timeout: timeout,
    );
    if (songsResponse.statusCode == 200) {
      final json = _decodeJson(
        utf8.decode(songsResponse.bodyBytes, allowMalformed: true),
      );
      final songs = _dig(json, ['data', 'info']);
      if (songs is List) {
        for (final raw in songs) {
          if (raw is! Map) continue;
          final duration = raw['duration'];
          if (targetSeconds != null &&
              duration is num &&
              (duration.toInt() - targetSeconds).abs() > 8) {
            continue;
          }
          final hash = raw['hash'];
          if (hash is! String || hash.isEmpty) continue;
          final candidate = await _searchKuGouLyrics(
            httpClient,
            hash: hash,
            timeout: timeout,
          );
          final lyrics = candidate == null
              ? null
              : await _downloadKuGouLyrics(
                  httpClient,
                  candidate,
                  timeout: timeout,
                );
          if (lyrics != null) return lyrics;
        }
      }
    }

    final candidate = await _searchKuGouLyrics(
      httpClient,
      keyword: keyword,
      durationSeconds: targetSeconds,
      timeout: timeout,
    );
    if (candidate == null) return null;
    return await _downloadKuGouLyrics(httpClient, candidate, timeout: timeout);
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

Future<Map?> _searchKuGouLyrics(
  http.Client client, {
  String? hash,
  String? keyword,
  int? durationSeconds,
  required Duration timeout,
}) async {
  final response = await _get(
    client,
    Uri.https('lyrics.kugou.com', '/search', {
      'ver': '1',
      'man': 'yes',
      'client': 'pc',
      if (hash != null) 'hash': hash,
      if (keyword != null) 'keyword': keyword,
      if (durationSeconds != null && durationSeconds > 0)
        'duration': (durationSeconds * 1000).toString(),
    }),
    timeout: timeout,
  );
  if (response.statusCode != 200) return null;

  final json = _decodeJson(
    utf8.decode(response.bodyBytes, allowMalformed: true),
  );
  final candidates = _dig(json, ['candidates']);
  if (candidates is! List) return null;
  for (final candidate in candidates) {
    if (candidate is Map &&
        candidate['id'] != null &&
        candidate['accesskey'] is String) {
      return candidate;
    }
  }
  return null;
}

Future<Lyrics?> _downloadKuGouLyrics(
  http.Client client,
  Map candidate, {
  required Duration timeout,
}) async {
  final response = await _get(
    client,
    Uri.https('lyrics.kugou.com', '/download', {
      'fmt': 'lrc',
      'charset': 'utf8',
      'client': 'pc',
      'ver': '1',
      'id': candidate['id'].toString(),
      'accesskey': candidate['accesskey'].toString(),
    }),
    timeout: timeout,
  );
  if (response.statusCode != 200) return null;

  final json = _decodeJson(
    utf8.decode(response.bodyBytes, allowMalformed: true),
  );
  final content = _dig(json, ['content']);
  if (content is! String || content.trim().isEmpty) return null;

  final decoded = utf8.decode(
    base64Decode(content.trim()),
    allowMalformed: true,
  );
  return lyricsFromRaw(decoded, 'KuGou');
}

// ----------------------------------------------------------------- Megalobiz

Future<Lyrics?> fetchMegalobiz(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;

  try {
    final searchResponse = await _get(
      httpClient,
      Uri.https('www.megalobiz.com', '/searchall', {'qry': '$artist $title'}),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      timeout: timeout,
    );
    if (searchResponse.statusCode != 200) return null;

    final searchHtml = utf8.decode(
      searchResponse.bodyBytes,
      allowMalformed: true,
    );
    final href = RegExp(r'''href=["'](/lrc/maker/download/[^"']+)["']''')
        .firstMatch(searchHtml)
        ?.group(1);
    if (href == null) return null;

    final detailResponse = await _get(
      httpClient,
      Uri.parse('https://www.megalobiz.com$href'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'},
      timeout: timeout,
    );
    if (detailResponse.statusCode != 200) return null;

    final detailHtml = utf8.decode(
      detailResponse.bodyBytes,
      allowMalformed: true,
    );
    final document = html_parser.parse(detailHtml);
    final span = document.querySelector(r'span[id^="lrc_"][id$="_details"]');
    var raw = span?.innerHtml ?? detailHtml;
    raw = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    raw = raw.replaceAll(RegExp(r'<[^>]+>'), '');
    raw = html_parser.parseFragment(raw).text ?? raw;
    return lyricsFromRaw(raw, 'Megalobiz');
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

// ------------------------------------------------------------------- Paxsenix

enum PaxsenixKind { appleMusic, spotify, musixmatch }

Future<Lyrics?> fetchPaxsenix(
  TrackInfo track,
  PaxsenixKind kind, {
  required String apiKey,
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final key = apiKey.trim();
  if (key.isEmpty) return null;
  final title = track.title.trim();
  final artist = track.artist.trim();
  if (title.isEmpty || artist.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;
  final headers = {
    'Authorization': 'Bearer $key',
    'Accept': 'application/json, text/plain, */*',
  };

  try {
    String? raw;
    switch (kind) {
      case PaxsenixKind.appleMusic:
        final id = await _paxsenixFindId(
          httpClient,
          'apple-music/search',
          track,
          headers,
          timeout,
        );
        if (id == null) return null;
        raw = await _paxsenixBody(
          httpClient,
          'lyrics/applemusic',
          {'id': id},
          headers,
          timeout,
        );
      case PaxsenixKind.spotify:
        final id = await _paxsenixFindId(
          httpClient,
          'spotify/search',
          track,
          headers,
          timeout,
        );
        if (id == null) return null;
        raw = await _paxsenixBody(
          httpClient,
          'lyrics/spotify',
          {'id': id},
          headers,
          timeout,
        );
      case PaxsenixKind.musixmatch:
        raw = await _paxsenixBody(
          httpClient,
          'lyrics/musixmatch',
          {
            't': title,
            'a': artist,
            if (track.duration != null && track.duration!.inSeconds > 0)
              'd': track.duration!.inSeconds.toString(),
          },
          headers,
          timeout,
        );
    }
    if (raw == null) return null;
    return _parsePaxsenixLyrics(raw, _paxsenixLabel(kind));
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

String _paxsenixLabel(PaxsenixKind kind) => switch (kind) {
  PaxsenixKind.appleMusic => 'Paxsenix · Apple Music',
  PaxsenixKind.spotify => 'Paxsenix · Spotify',
  PaxsenixKind.musixmatch => 'Paxsenix · Musixmatch',
};

Future<String?> _paxsenixBody(
  http.Client client,
  String path,
  Map<String, String> query,
  Map<String, String> headers,
  Duration timeout,
) async {
  final response = await _get(
    client,
    Uri.https('api.paxsenix.org', '/$path', query),
    headers: headers,
    timeout: timeout,
  );
  if (response.statusCode < 200 || response.statusCode >= 300) return null;
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}

Future<String?> _paxsenixFindId(
  http.Client client,
  String path,
  TrackInfo track,
  Map<String, String> headers,
  Duration timeout,
) async {
  final raw = await _paxsenixBody(
    client,
    path,
    {'q': '${track.title.trim()} ${track.artist.trim()}'},
    headers,
    timeout,
  );
  if (raw == null) return null;

  final json = _decodeJson(raw);
  final candidates = <Map>[];
  _collectTrackCandidates(json, candidates);
  if (candidates.isEmpty) return null;

  Map? best;
  var bestScore = 0;
  for (final candidate in candidates) {
    final score = _trackCandidateScore(candidate, track);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  if (best == null || bestScore < 10) return null;
  final id =
      best['id'] ?? best['trackId'] ?? best['track_id'] ?? best['realId'];
  return id?.toString();
}

void _collectTrackCandidates(Object? node, List<Map> out) {
  if (node is List) {
    for (final item in node) {
      _collectTrackCandidates(item, out);
    }
    return;
  }
  if (node is! Map) return;

  final id =
      node['id'] ?? node['trackId'] ?? node['track_id'] ?? node['realId'];
  final title = node['name'] ?? node['title'] ?? node['trackName'];
  if (id != null && title is String && title.trim().isNotEmpty) {
    out.add(node);
  }
  for (final value in node.values) {
    _collectTrackCandidates(value, out);
  }
}

int _trackCandidateScore(Map candidate, TrackInfo track) {
  final haveTitle =
      (candidate['name'] ?? candidate['title'] ?? candidate['trackName'] ?? '')
          .toString();
  final haveArtist =
      (candidate['artistName'] ??
              candidate['artist_name'] ??
              candidate['artist'] ??
              '')
          .toString();
  var score = _textScore(haveTitle, track.title, exact: 20, partial: 10);
  score += _textScore(haveArtist, track.artist, exact: 15, partial: 5);

  final seconds = track.duration?.inSeconds;
  final duration =
      candidate['durationInMillis'] ??
      candidate['durationMs'] ??
      candidate['duration_ms'] ??
      candidate['duration'];
  if (seconds != null && seconds > 0 && duration is num && duration > 0) {
    final durationSeconds = duration > 10000
        ? duration / 1000
        : duration.toDouble();
    final difference = (durationSeconds - seconds).abs();
    if (difference < 3) {
      score += 10;
    } else if (difference < 10) {
      score += 5;
    }
  }
  return score;
}

int _textScore(
  String candidate,
  String requested, {
  required int exact,
  required int partial,
}) {
  final have = candidate.toLowerCase().trim();
  final want = requested.toLowerCase().trim();
  if (have.isEmpty || want.isEmpty) return 0;
  if (have == want) return exact;
  if (have.contains(want) || want.contains(have)) return partial;
  return 0;
}

Lyrics? _parsePaxsenixLyrics(String raw, String source) {
  final json = _decodeJson(raw);
  if (_isPaxsenixError(json)) return null;

  final appleLines = _appleMusicToLrc(json);
  if (appleLines != null) {
    final lyrics = lyricsFromRaw(appleLines, source);
    if (lyrics != null) return lyrics;
  }

  final timed = _findLyricsString(json);
  if (timed != null) {
    final lyrics = lyricsFromRaw(timed, source);
    if (lyrics != null) return lyrics;
  }

  final plain = _findPlainLyrics(json);
  if (plain != null) return Lyrics(source: source, plain: plain);

  return lyricsFromRaw(raw, source);
}

bool _isPaxsenixError(Object? json) {
  if (json is! Map) return false;
  if (json['isError'] == true || json['ok'] == false) return true;
  final error = json['error'];
  return error != null &&
      error != false &&
      (error is! String || error.trim().isNotEmpty);
}

String? _appleMusicToLrc(Object? json) {
  if (json is! Map) return null;
  final content = json['content'];
  if (content is! List || content.isEmpty) return null;

  final lines = <String>[];
  for (final item in content) {
    if (item is! Map) continue;
    final timestamp = item['timestamp'];
    if (timestamp is! num) continue;
    final text = _appleMusicText(item['text']);
    if (text.isEmpty) continue;
    final milliseconds = timestamp.toInt();
    final minutes = milliseconds ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    final hundredths = (milliseconds % 1000) ~/ 10;
    final stamp =
        '[${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${hundredths.toString().padLeft(2, '0')}]';
    lines.add('$stamp$text');
  }
  return lines.isEmpty ? null : lines.join('\n');
}

String _appleMusicText(Object? value) {
  if (value is String) return value.trim();
  if (value is List) {
    return value
        .map((part) {
          if (part is Map) return (part['text'] ?? '').toString();
          return part?.toString() ?? '';
        })
        .join()
        .trim();
  }
  return '';
}

// ----------------------------------------------------------- YouTube Music

const _ytMusicPublicKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

Map<String, Object> _ytMusicContext(String clientName, String version) => {
  'client': {
    'clientName': clientName,
    'clientVersion': version,
    'hl': 'en',
    'gl': 'US',
    if (clientName == 'ANDROID_MUSIC') ...{
      'androidSdkVersion': 31,
      'osName': 'Android',
      'osVersion': '12',
      'platform': 'MOBILE',
    },
  },
};

Future<Lyrics?> fetchYouTubeMusic(
  TrackInfo track, {
  http.Client? client,
  Duration timeout = _defaultTimeout,
}) async {
  final videoId = track.videoId?.trim();
  if (videoId == null || videoId.isEmpty) return null;

  final httpClient = client ?? http.Client();
  final shouldClose = client == null;

  try {
    final nextResponse = await _postJson(
      httpClient,
      Uri.https('music.youtube.com', '/youtubei/v1/next', {
        'prettyPrint': 'false',
        'key': _ytMusicPublicKey,
      }),
      {
        'context': _ytMusicContext('WEB_REMIX', '1.20240101.01.00'),
        'videoId': videoId,
        'isAudioOnly': true,
      },
      headers: {
        'Origin': 'https://music.youtube.com',
        'X-Goog-Api-Format-Version': '2',
      },
      timeout: timeout,
    );
    if (nextResponse.statusCode != 200) return null;
    final nextJson = _decodeJson(
      utf8.decode(nextResponse.bodyBytes, allowMalformed: true),
    );
    final browseId = _youTubeMusicBrowseId(nextJson);
    if (browseId == null) return null;

    final timed = await _fetchYouTubeMusicBrowse(
      httpClient,
      browseId,
      androidMusic: true,
      timeout: timeout,
    );
    if (timed != null) return timed;

    return await _fetchYouTubeMusicBrowse(
      httpClient,
      browseId,
      androidMusic: false,
      timeout: timeout,
    );
  } catch (_) {
    return null;
  } finally {
    if (shouldClose) httpClient.close();
  }
}

String? _youTubeMusicBrowseId(Object? json) {
  final tabs = _dig(json, [
    'contents',
    'singleColumnMusicWatchNextResultsRenderer',
    'tabbedRenderer',
    'watchNextTabbedResultsRenderer',
    'tabs',
  ]);
  if (tabs is! List) return null;

  for (final tab in tabs) {
    if (tab is! Map) continue;
    final renderer = tab['tabRenderer'];
    if (renderer is! Map || renderer.containsKey('unselectable')) continue;
    final endpoint = _dig(renderer, ['endpoint', 'browseEndpoint']);
    if (endpoint is! Map) continue;
    final browseId = endpoint['browseId'];
    if (browseId is! String || browseId.isEmpty) continue;
    final pageType = _dig(endpoint, [
      'browseEndpointContextSupportedConfigs',
      'browseEndpointContextMusicConfig',
      'pageType',
    ]);
    if (pageType == 'MUSIC_PAGE_TYPE_TRACK_LYRICS' ||
        browseId.startsWith('MPLYt')) {
      return browseId;
    }
  }
  return null;
}

Future<Lyrics?> _fetchYouTubeMusicBrowse(
  http.Client client,
  String browseId, {
  required bool androidMusic,
  required Duration timeout,
}) async {
  final context = androidMusic
      ? _ytMusicContext('ANDROID_MUSIC', '7.21.50')
      : _ytMusicContext('WEB_REMIX', '1.20240101.01.00');
  final response = await _postJson(
    client,
    Uri.https('music.youtube.com', '/youtubei/v1/browse', {
      'prettyPrint': 'false',
      'key': _ytMusicPublicKey,
    }),
    {'context': context, 'browseId': browseId},
    headers: {
      'Origin': 'https://music.youtube.com',
      'X-Goog-Api-Format-Version': '2',
    },
    timeout: timeout,
  );
  if (response.statusCode != 200) return null;
  final json = _decodeJson(
    utf8.decode(response.bodyBytes, allowMalformed: true),
  );
  return _parseYouTubeMusicLyrics(json, timed: androidMusic);
}

Lyrics? _parseYouTubeMusicLyrics(Object? json, {required bool timed}) {
  if (timed) {
    final data = _dig(json, [
      'contents',
      'elementRenderer',
      'newElement',
      'type',
      'componentType',
      'model',
      'timedLyricsModel',
      'lyricsData',
      'timedLyricsData',
    ]);
    if (data is List) {
      final lines = <LyricLine>[];
      for (final item in data) {
        if (item is! Map) continue;
        final text = (item['lyricLine'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        final cue = item['cueRange'];
        final start = cue is Map ? cue['startTimeMilliseconds'] : null;
        final end = cue is Map ? cue['endTimeMilliseconds'] : null;
        if (start is! num) continue;
        lines.add(
          LyricLine(
            Duration(milliseconds: start.toInt()),
            text,
            end: end is num ? Duration(milliseconds: end.toInt()) : null,
          ),
        );
      }
      if (lines.isNotEmpty) {
        lines.sort((a, b) => a.start.compareTo(b.start));
        return Lyrics(
          source: 'YouTube Music',
          plain: lines.map((line) => line.text).join('\n'),
          synced: lines,
        );
      }
    }
  }

  final shelf = _dig(json, [
    'contents',
    'sectionListRenderer',
    'contents',
    0,
    'musicDescriptionShelfRenderer',
  ]);
  final description = shelf is Map ? shelf['description'] : null;
  final text = _runsText(description);
  if (text == null || text.isEmpty) return null;
  return Lyrics(source: 'YouTube Music', plain: text);
}

// --------------------------------------------------------- YouTube Subtitle

Future<Lyrics?> fetchYouTubeSubtitle(
  TrackInfo track,
  YoutubeExplode youtube, {
  Duration timeout = _defaultTimeout,
}) async {
  final videoId = track.videoId?.trim();
  if (videoId == null || videoId.isEmpty) return null;

  try {
    final manifest = await youtube.videos.closedCaptions
        .getManifest(videoId)
        .timeout(timeout);
    if (manifest.tracks.isEmpty) return null;

    var candidates = manifest.getByLanguage('en');
    if (candidates.isEmpty) candidates = manifest.tracks.toList();
    if (candidates.isEmpty) return null;

    // srv3 keeps line and word timing; ttml is the next best.
    candidates.sort((a, b) {
      int rank(ClosedCaptionTrackInfo info) {
        if (info.isAutoGenerated) return 10;
        if (info.format == ClosedCaptionFormat.srv3) return 0;
        if (info.format == ClosedCaptionFormat.ttml) return 1;
        return 2;
      }

      return rank(a).compareTo(rank(b));
    });

    final captionTrack = await youtube.videos.closedCaptions
        .get(candidates.first)
        .timeout(timeout);

    final lines = <LyricLine>[];
    for (final caption in captionTrack.captions) {
      final text = caption.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty || RegExp(r'^\[[^\]]+\]$').hasMatch(text)) continue;
      lines.add(LyricLine(caption.offset, text, end: caption.end));
    }
    if (lines.isEmpty) return null;

    lines.sort((a, b) => a.start.compareTo(b.start));
    return Lyrics(
      source: 'YouTube Subtitle',
      plain: lines.map((line) => line.text).join('\n'),
      synced: lines,
    );
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------- utilities

Object? _dig(Object? node, List<Object> path) {
  var current = node;
  for (final step in path) {
    if (step is int) {
      if (current is! List || step < 0 || step >= current.length) return null;
      current = current[step];
    } else {
      if (current is! Map) return null;
      current = current[step];
    }
  }
  return current;
}

String? _runsText(Object? node) {
  if (node is String) {
    final text = node.trim();
    return text.isEmpty ? null : text;
  }
  if (node is! Map) return null;

  final simple = node['simpleText'];
  if (simple is String && simple.trim().isNotEmpty) return simple.trim();

  final runs = node['runs'];
  if (runs is! List) return null;
  final buffer = StringBuffer();
  for (final run in runs) {
    if (run is Map && run['text'] is String) buffer.write(run['text']);
  }
  final text = buffer.toString().trim();
  return text.isEmpty ? null : text;
}
