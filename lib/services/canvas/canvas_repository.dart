/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:async';
import 'dart:collection';
import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:musify/services/canvas/canvas_artwork.dart';
import 'package:musify/services/canvas/sources/apple_music_canvas.dart';
import 'package:musify/services/canvas/sources/community_canvas.dart';
import 'package:musify/services/canvas/sources/tidal_canvas.dart';
import 'package:musify/services/settings_manager.dart'
    show canvasEnabled, canvasWifiOnly, offlineMode;

/// Resolves one matching looping cover from independent catalogues.
///
/// The first hit wins. Misses are cached too: no motion artwork is common and
/// asking every source again on each player open would waste network and time.
class CanvasRepository {
  CanvasRepository._();

  static final CanvasRepository instance = CanvasRepository._();

  static const int _maxEntries = 64;
  static const Duration _sourceTimeout = Duration(seconds: 6);

  final LinkedHashMap<String, CanvasArtwork?> _cache =
      LinkedHashMap<String, CanvasArtwork?>();
  final Map<String, Future<CanvasArtwork?>> _inFlight = {};

  CanvasArtwork? cached(MediaItem item) => _cache[_key(item)];

  Future<CanvasArtwork?> canvasFor(MediaItem item) async {
    final title = _clean(item.title);
    final artist = _clean(item.artist ?? '');
    final album = _clean(item.album ?? '');
    if (title.isEmpty || artist.isEmpty) return null;
    if (!canvasEnabled.value || offlineMode.value) return null;
    if (canvasWifiOnly.value && !await _isOnWifi()) return null;

    final key = _key(item);
    if (_cache.containsKey(key)) {
      final value = _cache.remove(key);
      _cache[key] = value;
      return value;
    }
    final running = _inFlight[key];
    if (running != null) return running;

    final future = _resolve(title, artist, album.isEmpty ? null : album);
    _inFlight[key] = future;
    try {
      final artwork = await future;
      _put(key, artwork);
      return artwork;
    } finally {
      _inFlight.remove(key)?.ignore();
    }
  }

  /// Starts a best-effort lookup for the next track without holding up
  /// playback. The result is available from [cached] on track transition.
  void preload(MediaItem? item) {
    if (item == null || !canvasEnabled.value || offlineMode.value) return;
    unawaited(canvasFor(item).catchError((Object _) => null));
  }

  Future<CanvasArtwork?> _resolve(
    String title,
    String artist,
    String? album,
  ) async {
    final lookups = <Future<CanvasArtwork?> Function()>[
      () => AppleMusicCanvas.instance.search(
        title: title,
        artist: artist,
        album: album,
      ),
      () => TidalCanvas.search(title: title, artist: artist, album: album),
      () => CommunityCanvas.search(title: title, artist: artist, album: album),
    ];
    for (final lookup in lookups) {
      try {
        final candidate = await lookup().timeout(_sourceTimeout);
        if (candidate == null) continue;
        if (candidate.matches(title, artist, album)) return candidate;
        developer.log(
          'Rejected canvas mismatch: ${candidate.title} / ${candidate.artist}',
          name: 'CanvasRepository',
        );
      } on TimeoutException {
        developer.log('Canvas source timed out', name: 'CanvasRepository');
      } catch (error) {
        developer.log('Canvas source failed: $error', name: 'CanvasRepository');
      }
    }
    return null;
  }

  Future<bool> _isOnWifi() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (_) {
      // If the platform cannot report connectivity, do not block the clip.
      return true;
    }
  }

  void _put(String key, CanvasArtwork? value) {
    _cache.remove(key);
    _cache[key] = value;
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
  }

  String _key(MediaItem item) =>
      '${_clean(item.title).toLowerCase()}|${_clean(item.artist ?? '').toLowerCase()}|${_clean(item.album ?? '').toLowerCase()}';

  String _clean(String value) => value
      .replaceAll(
        RegExp(
          r'\((?:from|official|lyrical|video|audio)[^)]*\)|\[[^]]*]|\b(?:official (?:video|audio|music video)|lyrical|full song|4k video)\b',
          caseSensitive: false,
        ),
        ' ',
      )
      .split(' | ')
      .first
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
