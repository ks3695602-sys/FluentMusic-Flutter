/*
 *     Copyright (C) 2026 jaypakash sahu
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
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:musify/services/account_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/logger_service.dart';
import 'package:musify/services/playlists_manager.dart';

/// Result of a sync/export/import operation.
class SyncResult {
  const SyncResult(this.success, this.message);

  final bool success;
  final String message;
}

/// Local-first library sync.
///
/// Everything is written to Hive first. Cloud sync is a merge of the local
/// snapshot into a single Supabase row; audio files and settings are never
/// uploaded. Deletions are intentionally not propagated in v1.4.0: two devices
/// converge by union, which is safe and never eats a user's library.
class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const int snapshotVersion = 1;

  static const List<String> _stringListKeys = <String>[
    'playlists',
    'pinnedPlaylistIds',
    'likedRadioStations',
  ];

  static const Map<String, String> _mapListKeys = <String, String>{
    'customPlaylists': 'ytid',
    'likedPlaylists': 'ytid',
    'likedSongs': 'ytid',
    'recentlyPlayedSongs': 'ytid',
    'playlistFolders': 'id',
  };

  bool get isCloudReady =>
      CloudSyncConfig.isConfigured && (accountService.session?.isCloud ?? false);

  bool get isPending =>
      Hive.box('settings').get('syncPending', defaultValue: false) == true;

  DateTime? get lastSyncedAt {
    final raw = Hive.box('settings').get('syncLastAt');
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool get autoSyncEnabled =>
      Hive.box('settings').get('syncAutoEnabled', defaultValue: true) == true;

  Future<void> setAutoSyncEnabled(bool value) async {
    await Hive.box('settings').put('syncAutoEnabled', value);
  }

  /// Plain-JSON snapshot of everything that belongs to the library.
  Map<String, dynamic> buildSnapshot() {
    final box = Hive.box('user');
    final snapshot = <String, dynamic>{
      'version': snapshotVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    };
    for (final key in _stringListKeys) {
      snapshot[key] = _plain(box.get(key, defaultValue: <dynamic>[]));
    }
    for (final key in _mapListKeys.keys) {
      snapshot[key] = _plain(box.get(key, defaultValue: <dynamic>[]));
    }
    return snapshot;
  }

  /// Merges a snapshot into Hive. Local values win; remote-only values are
  /// added. With [merge] false the snapshot replaces the local lists (used by
  /// explicit "restore from file" when the user wants an exact copy).
  Future<void> applySnapshot(
    Map<dynamic, dynamic> snapshot, {
    bool merge = true,
  }) async {
    final box = Hive.box('user');

    for (final key in _stringListKeys) {
      final local = box.get(key, defaultValue: <dynamic>[]);
      final incoming = snapshot[key];
      final next = merge
          ? _mergePrimitiveList(local, incoming)
          : _plain(incoming) ?? <dynamic>[];
      await box.put(key, next);
    }

    for (final entry in _mapListKeys.entries) {
      final local = box.get(entry.key, defaultValue: <dynamic>[]);
      final incoming = snapshot[entry.key];
      final next = merge
          ? _mergeObjectList(local, incoming, entry.value)
          : _plain(incoming) ?? <dynamic>[];
      await box.put(entry.key, next);
    }

    reloadSongLibraryStateFromStorage();
    reloadPlaylistLibraryStateFromStorage();
  }

  /// Merges remote → local, then uploads the merged snapshot.
  Future<SyncResult> syncNow() async {
    final session = accountService.session;
    if (session == null) {
      return const SyncResult(false, 'Sign in to sync your library');
    }
    if (session.isLocal) {
      return const SyncResult(
        false,
        'Local profile · cloud sync needs an account',
      );
    }
    if (!CloudSyncConfig.isConfigured) {
      return const SyncResult(false, 'Cloud sync is not configured');
    }

    final token = await accountService.validAccessToken();
    if (token == null || token.isEmpty) {
      return const SyncResult(false, 'Session expired · sign in again');
    }

    final settings = Hive.box('settings');
    await settings.put('syncPending', true);
    try {
      final remote = await _pull(token, session.userId);
      if (remote != null) {
        await applySnapshot(remote);
      }

      final merged = buildSnapshot();
      await _push(token, session.userId, merged);

      await settings.put(
        'syncLastAt',
        DateTime.now().toUtc().toIso8601String(),
      );
      await settings.put('syncPending', false);
      return const SyncResult(true, 'Library synced');
    } on TimeoutException {
      return const SyncResult(false, 'Sync timed out · will retry later');
    } catch (e, stackTrace) {
      logger.log('Cloud sync failed', error: e, stackTrace: stackTrace);
      return SyncResult(false, 'Sync failed: $e');
    }
  }

  /// Fire-and-forget launch sync. Never throws into the UI.
  Future<void> autoSyncOnLaunch() async {
    if (!autoSyncEnabled || !isCloudReady) return;
    try {
      await syncNow();
    } catch (e, stackTrace) {
      logger.log('Auto sync failed', error: e, stackTrace: stackTrace);
    }
  }

  Future<SyncResult> exportSnapshot() async {
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      final text = encoder.convert(buildSnapshot());
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final path = await FilePicker.saveFile(
        fileName: 'fluentmusic-backup-$stamp.json',
        type: FileType.custom,
        allowedExtensions: <String>['json'],
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (path == null) {
        return const SyncResult(false, 'Export cancelled');
      }
      return const SyncResult(true, 'Library exported');
    } catch (e, stackTrace) {
      logger.log('Snapshot export failed', error: e, stackTrace: stackTrace);
      return SyncResult(false, 'Export failed: $e');
    }
  }

  Future<SyncResult> importSnapshot() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (files.isEmpty) {
        return const SyncResult(false, 'Import cancelled');
      }
      final bytes = await files.single.readAsBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        return const SyncResult(false, 'Not a FluentMusic backup');
      }
      await applySnapshot(decoded);
      return const SyncResult(true, 'Library imported');
    } catch (e, stackTrace) {
      logger.log('Snapshot import failed', error: e, stackTrace: stackTrace);
      return SyncResult(false, 'Import failed: $e');
    }
  }

  Map<String, String> _headers(String token, {bool json = false}) {
    return <String, String>{
      'apikey': CloudSyncConfig.supabaseAnonKey,
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
  }

  Future<Map<String, dynamic>?> _pull(String token, String userId) async {
    final uri = Uri.parse(
      '${CloudSyncConfig.restBase}/user_sync'
      '?user_id=eq.${Uri.encodeComponent(userId)}'
      '&select=payload',
    );
    final response = await http
        .get(uri, headers: _headers(token))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Pull failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is List && decoded.isNotEmpty) {
      final row = decoded.first;
      if (row is Map && row['payload'] is Map) {
        return Map<String, dynamic>.from(row['payload'] as Map);
      }
    }
    return null;
  }

  Future<void> _push(
    String token,
    String userId,
    Map<String, dynamic> snapshot,
  ) async {
    final uri = Uri.parse('${CloudSyncConfig.restBase}/user_sync');
    final response = await http
        .post(
          uri,
          headers: <String, String>{
            ..._headers(token, json: true),
            'Prefer': 'resolution=merge-duplicates,return=minimal',
          },
          body: jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': userId,
              'payload': snapshot,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ]),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Push failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  dynamic _plain(dynamic value) {
    try {
      return jsonDecode(jsonEncode(value));
    } catch (_) {
      return value;
    }
  }

  List<dynamic> _mergePrimitiveList(dynamic local, dynamic incoming) {
    final result = <dynamic>[];
    final seen = <String>{};
    for (final source in <dynamic>[local, incoming]) {
      if (source is! Iterable) continue;
      for (final item in source) {
        if (item == null) continue;
        final key = item.toString();
        if (seen.add(key)) result.add(item);
      }
    }
    return result;
  }

  List<dynamic> _mergeObjectList(dynamic local, dynamic incoming, String key) {
    final result = <dynamic>[];
    final seen = <String>{};
    for (final source in <dynamic>[local, incoming]) {
      if (source is! Iterable) continue;
      for (final item in source) {
        if (item is! Map) continue;
        final id = item[key]?.toString() ?? '';
        if (id.isEmpty) {
          result.add(_plain(item));
          continue;
        }
        if (seen.add(id)) result.add(_plain(item));
      }
    }
    return result;
  }
}

final syncService = SyncService.instance;
