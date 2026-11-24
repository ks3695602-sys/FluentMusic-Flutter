/*
 * FluentMusic — YouTube Music library store
 *
 * Persists the account library snapshot in Hive and merges it into the app's
 * local library notifiers without ever deleting anything the user created on
 * this device:
 *   - playlists merged by `ytid`; only entries tagged `source: ytmusic` are
 *     replaced, so local likes and custom playlists survive a re-sync
 *   - liked songs appended (deduped by video id) and re-indexed
 *   - home shelves kept separately for the Listen Now account rails
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/innertube_client.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/ytmusic_auth_service.dart';
import 'package:musify/services/ytmusic_library_service.dart';

const _kPlaylists = 'ytmusicLibraryPlaylists';
const _kLikedSongs = 'ytmusicLikedSongs';
const _kHomeShelves = 'ytmusicHomeShelves';
const _kSyncedAt = 'ytmusicLibrarySyncedAt';

final ytMusicLibraryPlaylists = ValueNotifier<List<Map<String, dynamic>>>(
  _readMapList(_kPlaylists),
);
final ytMusicLikedSongs = ValueNotifier<List<Map<String, dynamic>>>(
  _readMapList(_kLikedSongs),
);
final ytMusicHomeShelves = ValueNotifier<List<YtMusicShelf>>(
  _readShelves(),
);
final ytMusicLastSync = ValueNotifier<DateTime?>(_readDate(_kSyncedAt));
final ytMusicSyncInProgress = ValueNotifier<bool>(false);

bool _syncing = false;

bool get hasYtMusicAccountLibrary =>
    ytMusicLibraryPlaylists.value.isNotEmpty ||
    ytMusicHomeShelves.value.isNotEmpty ||
    ytMusicLikedSongs.value.isNotEmpty;

List<Map<String, dynamic>> _readMapList(String key) {
  try {
    final raw = Hive.box('user').get(key, defaultValue: const []);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  } catch (_) {
    return const [];
  }
}

List<YtMusicShelf> _readShelves() {
  try {
    final raw = Hive.box('user').get(_kHomeShelves, defaultValue: const []);
    if (raw is! List) return const [];
    return raw
        .map(YtMusicShelf.fromJson)
        .whereType<YtMusicShelf>()
        .toList();
  } catch (_) {
    return const [];
  }
}

DateTime? _readDate(String key) {
  try {
    final raw = Hive.box('user').get(key);
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
  } catch (_) {}
  return null;
}

/// Re-reads the persisted snapshot. Safe to call before any network work.
Future<void> restoreYtMusicLibrary() async {
  ytMusicLibraryPlaylists.value = _readMapList(_kPlaylists);
  ytMusicLikedSongs.value = _readMapList(_kLikedSongs);
  ytMusicHomeShelves.value = _readShelves();
  ytMusicLastSync.value = _readDate(_kSyncedAt);
}

/// Syncs the account library, then merges it into the local library.
///
/// Throws [InnerTubeAuthException] when the session is missing/expired so the
/// caller can show the real reason instead of a generic failure.
Future<YtMusicLibrarySnapshot> syncYtMusicLibrary({
  bool includeHome = true,
}) async {
  if (!ytMusicAuthService.isConnected) {
    throw InnerTubeAuthException('Sign in to YouTube Music first.');
  }
  if (_syncing) {
    return YtMusicLibrarySnapshot(
      playlists: ytMusicLibraryPlaylists.value,
      likedSongs: ytMusicLikedSongs.value,
      homeShelves: ytMusicHomeShelves.value,
    );
  }

  _syncing = true;
  ytMusicSyncInProgress.value = true;
  try {
    final snapshot = await ytMusicLibraryService.fetchLibrary(
      includeHome: includeHome,
    );

    ytMusicLibraryPlaylists.value = snapshot.playlists;
    ytMusicLikedSongs.value = snapshot.likedSongs;
    ytMusicHomeShelves.value = snapshot.homeShelves;
    ytMusicLastSync.value = DateTime.now();

    await Future.wait([
      addOrUpdateData<List<Map<String, dynamic>>>(
        'user',
        _kPlaylists,
        snapshot.playlists,
      ),
      addOrUpdateData<List<Map<String, dynamic>>>(
        'user',
        _kLikedSongs,
        snapshot.likedSongs,
      ),
      addOrUpdateData<List<Map<String, dynamic>>>(
        'user',
        _kHomeShelves,
        snapshot.homeShelves.map((shelf) => shelf.toJson()).toList(),
      ),
      addOrUpdateData<DateTime>('user', _kSyncedAt, ytMusicLastSync.value!),
    ]);

    _mergePlaylists(snapshot.playlists);
    _mergeLikedSongs(snapshot.likedSongs);
    return snapshot;
  } finally {
    _syncing = false;
    ytMusicSyncInProgress.value = false;
  }
}

/// Quiet refresh used on launch and when Listen Now opens.
Future<YtMusicLibrarySnapshot?> autoSyncYtMusicLibrary({
  Duration minInterval = const Duration(hours: 6),
}) async {
  if (!ytMusicAuthService.isConnected) return null;
  final last = ytMusicLastSync.value;
  if (last != null && DateTime.now().difference(last) < minInterval) {
    return null;
  }
  try {
    return await syncYtMusicLibrary();
  } catch (error) {
    logger.log('YouTube Music library auto-sync failed', error: error);
    return null;
  }
}

void _mergePlaylists(List<Map<String, dynamic>> synced) {
  final merged = <Map>[
    ...userLikedPlaylists.value.where(
      (playlist) => playlist['source'] != 'ytmusic',
    ),
  ];
  final ids = merged
      .map((playlist) => playlist['ytid']?.toString())
      .whereType<String>()
      .toSet();

  for (final playlist in synced) {
    final id = playlist['ytid']?.toString();
    if (id == null || id.isEmpty || !ids.add(id)) continue;
    merged.add(playlist);
  }

  userLikedPlaylists.value = List<Map>.from(merged);
  unawaited(
    addOrUpdateData<List<Map>>(
      'user',
      'likedPlaylists',
      userLikedPlaylists.value,
    ),
  );
}

void _mergeLikedSongs(List<Map<String, dynamic>> synced) {
  final merged = <Map>[
    ...userLikedSongsList.value.where((song) => song['source'] != 'ytmusic'),
  ];
  final ids = merged
      .map((song) => song['ytid']?.toString())
      .whereType<String>()
      .toSet();

  for (final song in synced) {
    final id = song['ytid']?.toString();
    if (id == null || id.isEmpty || !ids.add(id)) continue;
    merged.add(song);
  }

  for (var i = 0; i < merged.length; i++) {
    merged[i]['id'] = i;
  }

  userLikedSongsList.value = merged;
  unawaited(addOrUpdateData<List>('user', 'likedSongs', merged));
}
