/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:async';
import 'dart:convert';

import 'package:musify/services/canvas/canvas_artwork.dart';
import 'package:musify/services/canvas/canvas_http.dart';

/// A community-curated `song + artist -> looping video` index. The manifest is
/// fetched as one bounded request and retained for thirty minutes.
class CommunityCanvas {
  CommunityCanvas._();

  static const String _manifestUrl =
      'https://vivimusicanvas.mkmdevilmi.workers.dev/canvas.json';
  static const Duration _ttl = Duration(minutes: 30);

  static List<Map<String, dynamic>> _entries = const [];
  static DateTime? _fetchedAt;
  static Future<void>? _fetching;

  static Future<CanvasArtwork?> search({
    required String title,
    required String artist,
    String? album,
  }) async {
    final entries = await _manifest();
    final wantedTitle = title.normalizeForMatch();
    final wantedArtist = artist.normalizeForMatch();
    final wantedAlbum = album?.normalizeForMatch();

    for (final entry in entries) {
      final song = (_value(entry, 'song') ?? '').normalizeForMatch();
      final credited = (_value(entry, 'artist') ?? '').normalizeForMatch();
      final listedAlbum = (_value(entry, 'album') ?? '').normalizeForMatch();
      final url = _value(entry, 'url');
      if (url == null || song.isEmpty || credited.isEmpty) continue;
      final titleMatch =
          wantedTitle == song ||
          wantedTitle.contains(song) ||
          song.contains(wantedTitle);
      final artistMatch =
          wantedArtist == credited ||
          wantedArtist.contains(credited) ||
          credited.contains(wantedArtist);
      final albumMatch =
          listedAlbum.isEmpty ||
          wantedAlbum == null ||
          wantedAlbum.isEmpty ||
          listedAlbum == wantedAlbum;
      if (!titleMatch || !artistMatch || !albumMatch) continue;
      return CanvasArtwork(
        url: url,
        title: _value(entry, 'song'),
        artist: _value(entry, 'artist'),
        album: _value(entry, 'album'),
      );
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> _manifest() async {
    final fetched = _fetchedAt;
    if (fetched != null && DateTime.now().difference(fetched) < _ttl) {
      return _entries;
    }
    final existing = _fetching;
    if (existing != null) {
      await existing;
      return _entries;
    }

    final completer = Completer<void>();
    _fetching = completer.future;
    try {
      final body = await CanvasHttp.getText(Uri.parse(_manifestUrl));
      if (body != null) {
        final decoded = jsonDecode(body);
        final items = decoded is Map ? decoded['items'] : null;
        if (items is List) {
          _entries = items
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .where(
                (item) =>
                    _value(item, 'song') != null &&
                    _value(item, 'artist') != null &&
                    _value(item, 'url') != null,
              )
              .toList(growable: false);
        }
      }
    } catch (_) {
      // Keep any last-known-good manifest; a temporary provider outage is a
      // miss, not a playback error.
    } finally {
      _fetchedAt = DateTime.now();
      completer.complete();
      _fetching = null;
    }
    return _entries;
  }

  static String? _value(Map<String, dynamic> map, String key) {
    final value = map[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
