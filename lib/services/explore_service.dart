/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
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

import 'package:musify/models/explore_feed.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';

export 'package:musify/models/explore_feed.dart';

/// Loads and caches the Explore feed.
///
/// The feed is deliberately assembled from the same YouTube Music search
/// service the rest of the app uses, so every card can be played with the
/// normal queue and resolved through the normal stream cache. The cache keeps
/// tab switches instant; a manual refresh bypasses it.
class ExploreService {
  ExploreService._();

  static final ExploreService instance = ExploreService._();

  static const _cacheLifetime = Duration(minutes: 20);

  ExploreFeed? _cached;
  Future<ExploreFeed>? _inFlight;

  /// The last successfully loaded feed, if any.
  ExploreFeed? get cached {
    final cached = _cached;
    if (cached == null) return null;
    if (DateTime.now().difference(cached.fetchedAt) > _cacheLifetime) {
      return null;
    }
    return cached;
  }

  /// Loads the feed, reusing the session cache unless [force] is set.
  Future<ExploreFeed> load({bool force = false}) {
    if (!force) {
      final cachedFeed = cached;
      if (cachedFeed != null) return Future.value(cachedFeed);
    }

    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    final future = _fetch();
    _inFlight = future;
    unawaited(
      future.then<void>(
        (_) => _releaseInFlight(future),
        onError: (Object _, StackTrace __) => _releaseInFlight(future),
      ),
    );
    return future;
  }

  void _releaseInFlight(Future<ExploreFeed> future) {
    if (identical(_inFlight, future)) _inFlight = null;
  }

  Future<ExploreFeed> _fetch() async {
    // Kick every request off together; each has its own failure fallback so a
    // single dead search never blanks the whole page.
    final newSongsFuture = _safeList(fetchSongsList('new music this week'));
    final trendingFuture = _safeList(fetchSongsList('trending songs'));
    final evergreenFuture = _safeList(
      fetchSongsList('classic hits everyone knows'),
    );
    final topPlaylistsFuture = _safeList(
      getPlaylists(query: 'top hits', type: 'playlist'),
    );
    final chillPlaylistsFuture = _safeList(
      getPlaylists(query: 'chill playlist', type: 'playlist'),
    );

    final newSongs = _songs(await newSongsFuture);
    final trendingSongs = _songs(await trendingFuture);
    final evergreenSongs = _songs(await evergreenFuture);
    final topPlaylists = _playlists(await topPlaylistsFuture);
    final chillPlaylists = _playlists(await chillPlaylistsFuture);

    final shorts = mixExploreSongs(
      [newSongs, trendingSongs, evergreenSongs],
      exploreShortCategories,
      limit: 12,
    );
    final songPicks = mixExploreSongs(
      [trendingSongs, evergreenSongs, newSongs],
      const ['Trending', 'Evergreen', 'New'],
      limit: 10,
    );

    // Curated playlists prefer editorial search results, then fall back to
    // the playlists already cached on the device. Featured banners reuse the
    // strongest playlist results so they never open an empty rail.
    var localPlaylists = <Map<String, dynamic>>[];
    try {
      final local = await getPlaylists(playlistsNum: 12);
      localPlaylists = _playlists(local);
    } catch (_) {
      localPlaylists = <Map<String, dynamic>>[];
    }

    final featuredSource = topPlaylists.isNotEmpty
        ? topPlaylists
        : chillPlaylists;
    final featured = _dedupePlaylists([
      ...featuredSource,
      ...localPlaylists,
    ]).take(4).toList(growable: false);

    final curated = _dedupePlaylists([
      ...chillPlaylists,
      ...topPlaylists.skip(4),
      ...localPlaylists,
      ...featured,
    ]).take(10).toList(growable: false);

    final feed = ExploreFeed(
      shorts: shorts,
      featured: featured,
      curated: curated,
      songPicks: songPicks,
      fetchedAt: DateTime.now(),
    );

    // Never cache a completely empty result: a temporary network failure
    // should not lock Explore out for the whole cache lifetime.
    if (!feed.isEmpty) _cached = feed;
    return feed;
  }

  static Future<List> _safeList(Future<List> future) async {
    try {
      return await future;
    } catch (_) {
      return const [];
    }
  }

  static List<Map<String, dynamic>> _songs(List raw) {
    return raw
        .map(normalizeExploreSong)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _playlists(List raw) {
    return raw
        .map(normalizeExplorePlaylist)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _dedupePlaylists(
    Iterable<Map<String, dynamic>> playlists,
  ) {
    final seen = <String>{};
    final result = <Map<String, dynamic>>[];
    for (final playlist in playlists) {
      final id = playlist['ytid']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      result.add(playlist);
    }
    return result;
  }
}
