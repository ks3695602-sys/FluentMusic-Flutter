/*
 * Portions derived from ZenMusic (vorlon-dev/Zen-music), GPL-3.0.
 * https://github.com/vorlon-dev/Zen-music
 *
 * FluentMusic is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 */

import 'dart:async';
import 'dart:developer' as developer;

import 'package:musify/constants/clients.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// One stream resolved by the Zen fast path.
class ZenStream {
  const ZenStream({
    required this.stream,
    required this.client,
    required this.resolvedAt,
  });

  final AudioOnlyStreamInfo stream;
  final YoutubeApiClient client;
  final DateTime resolvedAt;

  bool get isExpired =>
      DateTime.now().difference(resolvedAt) > ZenStreamResolver.cacheTtl;
}

/// ZenMusic's tokenless resolver, kept ahead of the full InnerTube ladder.
///
/// Zen asks three native identities, one request each, without a watch page
/// and without a boundary probe. That is enough for the common case; the
/// existing FluentMusic ladder (BotGuard, TV, WEB_REMIX, proxy and Cobalt)
/// still runs whenever all three refuse the track.
class ZenStreamResolver {
  ZenStreamResolver._();

  static final ZenStreamResolver instance = ZenStreamResolver._();

  /// ZenMusic's `kYtClientPriority`. [YoutubeApiClient.ios] is the same
  /// 21.26.4 payload the vendored extractor ships, so no package upgrade is
  /// needed.
  ///
  /// Not const: [YoutubeApiClient] instances are built from maps at runtime.
  static final List<YoutubeApiClient> clients = [
    YoutubeApiClient.visionOs,
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
  ];

  static const Duration perClientTimeout = Duration(seconds: 4);
  static const Duration totalBudget = Duration(seconds: 8);
  static const Duration cacheTtl = Duration(minutes: 10);
  static const int maxCachedStreams = 32;

  final Map<String, ZenStream> _cache = {};
  final Map<String, Future<ZenStream?>> _inFlight = {};

  /// Resolves [videoId] through the Zen identities, reusing a recent result.
  ///
  /// The cache is deliberately short-lived: googlevideo URLs are minted with
  /// an expiry and a client identity, so a stale URL would 403. FluentMusic's
  /// Hive URL cache remains the long-lived layer; this one only avoids
  /// re-minting while a queue transition or preload is in flight.
  Future<ZenStream?> resolve(
    String videoId, {
    required YoutubeExplode youtube,
  }) {
    final key = '${videoId}_${audioQualitySetting.value}';
    final cached = _cache[key];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached);
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _resolve(videoId, key, youtube);
    _inFlight[key] = future;
    unawaited(
      future.whenComplete(() {
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      }),
    );
    return future;
  }

  Future<ZenStream?> _resolve(
    String videoId,
    String key,
    YoutubeExplode youtube,
  ) async {
    final deadline = DateTime.now().add(totalBudget);

    for (final client in clients) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= const Duration(milliseconds: 250)) break;
      final timeout = remaining < perClientTimeout
          ? remaining
          : perClientTimeout;
      final watch = Stopwatch()..start();

      try {
        // Zen's resolver: no watch-page request, one client per attempt.
        final manifest = await youtube.videos.streams
            .getManifest(videoId, ytClients: [client])
            .timeout(timeout);

        // Clients behind the PO-token/SABR wall can return descriptors with
        // empty URLs. Zen skips those instead of probing them.
        final usable = manifest.audioOnly
            .where((stream) => stream.url.host.isNotEmpty)
            .toList(growable: false);
        if (usable.isEmpty) {
          throw StateError('no usable audio URL');
        }

        final selected = selectAudioOnlyStreamForQuality(usable);
        if (selected == null) {
          throw StateError('no compatible audio stream');
        }

        // Playback must send the User-Agent of the identity that minted the
        // URL, otherwise googlevideo answers 403.
        rememberSongClient(videoId, client);

        final result = ZenStream(
          stream: selected,
          client: client,
          resolvedAt: DateTime.now(),
        );
        _cache[key] = result;
        _pruneCache();
        developer.log(
          'stream timing: zen ${client.clientName} ok for $videoId in '
          '${watch.elapsedMilliseconds}ms',
          name: 'ZenStream',
        );
        return result;
      } catch (error) {
        developer.log(
          'stream timing: zen ${client.clientName} failed for $videoId in '
          '${watch.elapsedMilliseconds}ms: $error',
          name: 'ZenStream',
        );
      }
    }

    developer.log('stream timing: zen miss for $videoId', name: 'ZenStream');
    return null;
  }

  void _pruneCache() {
    if (_cache.length <= maxCachedStreams) return;
    _cache.removeWhere((_, value) => value.isExpired);
    while (_cache.length > maxCachedStreams) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Drops a resolved stream, e.g. when playback reports a 403.
  void invalidate(String videoId) {
    _cache.removeWhere((key, _) => key.startsWith('${videoId}_'));
  }
}
