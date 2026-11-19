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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musify/services/sources/music_source.dart';

/// JioSaavn as a last-resort streaming source.
///
/// Asked only after every YouTube identity has refused a track: a title and
/// artist search, a strict match, and the highest-bitrate URL the catalogue
/// hands back. No account, no cookie, nothing but the search terms leave the
/// device.
class JioSaavnSource implements MusicSource {
  JioSaavnSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint = 'https://saavn.dev/api/search/songs';
  static const _timeout = Duration(seconds: 8);

  @override
  String get id => 'jiosaavn';

  @override
  String get name => 'JioSaavn';

  @override
  bool get supportsStreaming => true;

  @override
  String? get limitation => null;

  @override
  Future<String?> resolveStreamUrl({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    final query = Uri(
      scheme: 'https',
      host: 'saavn.dev',
      path: '/api/search/songs',
      queryParameters: {
        'query': '$title $artist',
        'limit': '10',
      },
    );

    final response = await _client.get(query).timeout(_timeout);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['success'] == false) return null;

    final data = decoded['data'];
    final results = data is Map ? data['results'] : null;
    if (results is! List || results.isEmpty) return null;

    _Candidate? best;
    for (final entry in results) {
      if (entry is! Map) continue;
      final candidate = _Candidate.fromJson(entry);
      if (candidate.url == null) continue;

      final score = _score(
        candidate,
        title: title,
        artist: artist,
        duration: duration,
      );
      if (score < 0.55) continue;
      if (best == null || score > best.score) {
        best = candidate.copyWithScore(score);
      }
    }

    if (best == null) return null;
    // A remix or a live version can beat the studio cut on title alone; the
    // duration is the cheapest way to tell them apart.
    return best.url;
  }

  double _score(
    _Candidate candidate, {
    required String title,
    required String artist,
    Duration? duration,
  }) {
    final titleScore = _similarity(title, candidate.title);
    final artistScore = _similarity(artist, candidate.artist);

    var score = titleScore * 0.72 + artistScore * 0.28;

    if (duration != null && candidate.durationSeconds != null) {
      final difference =
          (duration.inSeconds - candidate.durationSeconds!).abs();
      if (difference > 12) {
        score -= 0.35;
      } else if (difference > 6) {
        score -= 0.15;
      }
    }

    return score;
  }
}

class _Candidate {
  _Candidate({
    required this.title,
    required this.artist,
    required this.url,
    required this.durationSeconds,
    this.score = 0,
  });

  final String title;
  final String artist;
  final String? url;
  final int? durationSeconds;
  final double score;

  _Candidate copyWithScore(double value) => _Candidate(
        title: title,
        artist: artist,
        url: url,
        durationSeconds: durationSeconds,
        score: value,
      );

  static _Candidate fromJson(Map<dynamic, dynamic> json) {
    final title = json['name']?.toString() ?? '';

    final artists = json['artists'];
    var artist = '';
    if (artists is Map) {
      final primary = artists['primary'];
      if (primary is List && primary.isNotEmpty) {
        final first = primary.first;
        if (first is Map) artist = first['name']?.toString() ?? '';
      }
      if (artist.isEmpty) {
        final all = artists['all'];
        if (all is List && all.isNotEmpty) {
          final first = all.first;
          if (first is Map) artist = first['name']?.toString() ?? '';
        }
      }
    }
    if (artist.isEmpty) artist = json['primaryArtists']?.toString() ?? '';

    final downloads = json['downloadUrl'] ?? json['downloadUrls'];
    String? bestUrl;
    var bestQuality = -1;
    if (downloads is List) {
      for (final entry in downloads) {
        if (entry is! Map) continue;
        final url = entry['url']?.toString();
        if (url == null || url.isEmpty) continue;
        final quality = int.tryParse(
              RegExp(r'(\d+)').firstMatch('${entry['quality'] ?? ''}')
                      ?.group(1) ??
                  '',
            ) ??
            128;
        if (quality > bestQuality) {
          bestQuality = quality;
          bestUrl = url;
        }
      }
    }

    final durationValue = json['duration'];
    final duration = durationValue is num
        ? durationValue.toInt()
        : int.tryParse('${durationValue ?? ''}');

    return _Candidate(
      title: title,
      artist: artist,
      url: bestUrl,
      durationSeconds: duration,
    );
  }
}

/// Compares two titles or artists, tolerant of punctuation, "(Remastered)"
/// tails and "feat." credits.
double _similarity(String a, String b) {
  final left = _tokens(a);
  final right = _tokens(b);
  if (left.isEmpty || right.isEmpty) return 0;

  final common = left.intersection(right).length;
  final union = left.union(right).length;
  final jaccard = common / union;

  final normalisedA = _normalise(a);
  final normalisedB = _normalise(b);
  final contains = normalisedA.contains(normalisedB) ||
          normalisedB.contains(normalisedA)
      ? 0.18
      : 0.0;

  return (jaccard + contains).clamp(0.0, 1.0).toDouble();
}

String _normalise(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'\([^)]*\)|\[[^\]]*\]'), ' ')
    .replaceAll(RegExp(r'\b(feat|ft|featuring|remastered|remaster|version)\b'),
        ' ')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Set<String> _tokens(String value) => _normalise(value)
    .split(' ')
    .where((token) => token.length > 1)
    .toSet();