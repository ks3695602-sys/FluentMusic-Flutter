/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:musify/services/canvas/canvas_artwork.dart';
import 'package:musify/services/canvas/canvas_http.dart';

/// Tidal's public "video cover" catalogue. It requires no user account or
/// Spotify token: a track search carries a videoCover id when a motion sleeve
/// is available.
class TidalCanvas {
  TidalCanvas._();

  static const _search = 'https://api.tidal.com/v1/search';
  static const _embedToken = 'vNVdglQOjFJJGG2U';

  static Future<CanvasArtwork?> search({
    required String title,
    required String artist,
    String? album,
  }) async {
    final query = album == null || album.isEmpty
        ? '$artist $title'
        : '$album $artist $title';
    final uri = Uri.parse(_search).replace(
      queryParameters: {
        'query': query,
        'limit': '10',
        'types': 'TRACKS',
        'countryCode': _countryCode,
      },
    );
    final root = await _get(uri);
    final tracks = _asList(_asMap(root?['tracks'])?['items']);

    for (final value in tracks) {
      final track = _asMap(value);
      if (track == null) continue;
      final trackTitle = _asString(track['title']);
      if (trackTitle == null ||
          trackTitle.normalizeForMatch() != title.normalizeForMatch()) {
        continue;
      }
      final credits = _asList(track['artists'])
          .map((artist) => _asString(_asMap(artist)?['name']))
          .whereType<String>()
          .toList(growable: false);
      final wanted = splitArtists(artist);
      final actual = credits.map((credit) => credit.normalizeForMatch());
      if (wanted.isEmpty || !wanted.every(actual.contains)) {
        continue;
      }

      final albumObj = _asMap(track['album']);
      final videoId = _asString(albumObj?['videoCover']);
      final videoUrl = videoId == null ? null : _coverUrl(videoId);
      if (videoUrl == null) continue;
      return CanvasArtwork(
        url: videoUrl,
        title: trackTitle,
        artist: credits.join(', '),
        album: _asString(albumObj?['title']),
        source: CanvasSource.tidal,
      );
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _get(Uri uri) async {
    final body = await CanvasHttp.getText(
      uri,
      headers: {'X-Tidal-Token': _embedToken},
    );
    if (body == null) return null;
    try {
      final decoded = jsonDecode(body);
      return _asMap(decoded);
    } catch (_) {
      return null;
    }
  }

  static String get _countryCode {
    final locale = Platform.localeName.replaceAll('-', '_');
    final parts = locale.split('_');
    final country = parts.length > 1 ? parts.last : '';
    return country.length == 2 ? country.toUpperCase() : 'US';
  }

  static String? _coverUrl(String id) {
    final parts = id.split('-');
    if (parts.length != 5 || parts.any((part) => part.isEmpty)) return null;
    return 'https://resources.tidal.com/videos/${parts.join('/')}/1280x1280.mp4';
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

String? _asString(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? null : result;
}
