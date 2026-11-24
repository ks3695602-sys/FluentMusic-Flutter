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
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:musify/services/sources/music_source.dart';
import 'package:pointycastle/export.dart';

/// JioSaavn as a last-resort streaming source.
///
/// Asked only after every YouTube identity has refused a track: a title and
/// artist search against JioSaavn's own web API, a strict match, and the
/// highest-bitrate URL the catalogue hands back. No account, no cookie,
/// nothing but the search terms leave the device.
///
/// The web API protects its catalogue with a single-DES envelope around the
/// media URL. It is the same envelope the official web player opens, and the
/// key below is the public constant every JioSaavn client uses.
class JioSaavnSource implements MusicSource {
  JioSaavnSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);

  /// JioSaavn answers this endpoint for an ordinary browser identity. The
  /// mobile app identity is not needed and would only add a missing client
  /// header.
  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36';

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
      host: 'www.jiosaavn.com',
      path: '/api.php',
      queryParameters: {
        '__call': 'search.getResults',
        'q': '$title $artist',
        'n': '10',
        'p': '1',
        '_format': 'json',
        '_marker': '0',
        'api_version': '4',
        'ctx': 'web6dot0',
      },
    );

    final response = await _client
        .get(
          query,
          headers: {
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;

    final results = decoded['results'];
    if (results is! List || results.isEmpty) return null;

    _Candidate? best;
    for (final entry in results) {
      if (entry is! Map) continue;
      final candidate = _Candidate.fromJson(entry);
      if (candidate == null) continue;

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

/// The public envelope key for JioSaavn's media URLs.
const _envelopeKey = '38346591';

/// Opens the single-DES envelope around a JioSaavn media URL.
///
/// JioSaavn uses plain DES-ECB with PKCS#7 padding. PointyCastle ships triple
/// DES but not its single-DES engine, and EDE with three identical subkeys is
/// exactly single DES, so the same eight bytes are repeated three times.
String decryptJioSaavnMediaUrl(String encrypted) {
  final encoded = base64Decode(encrypted);
  final keyBytes = utf8.encode(_envelopeKey);
  final key = Uint8List(keyBytes.length * 3);
  for (var i = 0; i < key.length; i++) {
    key[i] = keyBytes[i % keyBytes.length];
  }

  final cipher = PaddedBlockCipherImpl(
    PKCS7Padding(),
    ECBBlockCipher(DESedeEngine()),
  )..init(
      false,
      PaddedBlockCipherParameters<KeyParameter, Null>(
        KeyParameter(key),
        null,
      ),
    );

  final plain = cipher.process(encoded);
  return utf8.decode(plain, allowMalformed: true).trim();
}

/// Visible to the unit test so the envelope is checked without a network call.
@visibleForTesting
String decryptJioSaavnMediaUrlForTest(String encrypted) =>
    decryptJioSaavnMediaUrl(encrypted);

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
  final String url;
  final int? durationSeconds;
  final double score;

  _Candidate copyWithScore(double value) => _Candidate(
        title: title,
        artist: artist,
        url: url,
        durationSeconds: durationSeconds,
        score: value,
      );

  /// Reads one search result, or returns null when it carries no playable
  /// media URL (podcasts, clips and some regional rows do not).
  static _Candidate? fromJson(Map<dynamic, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    if (title.isEmpty) return null;

    final more = json['more_info'];
    if (more is! Map) return null;

    final encrypted = more['encrypted_media_url'];
    if (encrypted is! String || encrypted.isEmpty) return null;

    String url;
    try {
      url = decryptJioSaavnMediaUrl(encrypted);
    } catch (_) {
      return null;
    }
    if (url.isEmpty) return null;

    // The envelope always points at the 96 kbps file. Tracks flagged as
    // 320 kbps have a better file at the predictable suffix.
    if (more['320kbps']?.toString() == 'true' && url.contains('_96.mp4')) {
      url = url.replaceFirst('_96.mp4', '_320.mp4');
    }

    final durationRaw = more['duration']?.toString();
    final durationSeconds = int.tryParse(durationRaw ?? '');

    return _Candidate(
      title: title,
      artist: _artistOf(json, more),
      url: url,
      durationSeconds: durationSeconds,
    );
  }

  static String _artistOf(Map<dynamic, dynamic> json, Map<dynamic, dynamic> more) {
    final artistMap = more['artistMap'];
    if (artistMap is Map) {
      final primary = artistMap['primary_artists'];
      if (primary is List) {
        final names = <String>[];
        for (final entry in primary) {
          if (entry is Map) {
            final name = entry['name']?.toString();
            if (name != null && name.isNotEmpty) names.add(name);
          }
        }
        if (names.isNotEmpty) return names.join(', ');
      }
    }

    // Fallback: the subtitle is "composer, singer - album".
    final subtitle = json['subtitle']?.toString() ?? '';
    final front = subtitle.split(' - ').first;
    return front.trim();
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