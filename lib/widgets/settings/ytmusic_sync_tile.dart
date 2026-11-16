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
 */

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/services/ytmusic_auth_service.dart';
import 'package:musify/services/ytmusic_library_store.dart';
import 'package:musify/widgets/glass/glass_toast.dart';

/// Manual + automatic YouTube Music library sync, shown inside the account
/// card once a session is connected.
class YtMusicSyncTile extends StatefulWidget {
  const YtMusicSyncTile({super.key});

  @override
  State<YtMusicSyncTile> createState() => _YtMusicSyncTileState();
}

class _YtMusicSyncTileState extends State<YtMusicSyncTile> {
  @override
  void initState() {
    super.initState();
    // Quiet refresh: no spinner in the user's face unless it takes a while.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(autoSyncYtMusicLibrary());
    });
  }

  Future<void> _sync({bool manual = true}) async {
    if (!ytMusicAuthService.isConnected) return;
    try {
      final snapshot = await syncYtMusicLibrary();
      if (!mounted) return;
      showGlassToast(
        context,
        'Synced ${snapshot.playlistCount} playlists · '
        '${snapshot.songCount} liked songs',
        icon: CupertinoIcons.checkmark_seal_fill,
      );
    } catch (error) {
      if (!mounted) return;
      showGlassToast(
        context,
        manual ? 'Sync failed. Check the connection and retry.' : 'Sync failed',
        icon: CupertinoIcons.exclamationmark_triangle,
      );
      debugPrint('YouTube Music sync failed: ${error.runtimeType}');
    }
  }

  String _subtitle() {
    final last = ytMusicLastSync.value;
    final playlists = ytMusicLibraryPlaylists.value.length;
    final songs = ytMusicLikedSongs.value.length;
    if (last == null) {
      return 'Pull your playlists, liked songs and account picks';
    }
    return '$playlists playlists · $songs songs · ${_relative(last)}';
  }

  String _relative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        ytMusicSyncInProgress,
        ytMusicLastSync,
        ytMusicLibraryPlaylists,
        ytMusicLikedSongs,
      ]),
      builder: (context, _) {
        final syncing = ytMusicSyncInProgress.value;
        return GlassListTile(
          leading: Icon(
            syncing ? CupertinoIcons.arrow_2_circlepath : CupertinoIcons.cloud,
            color: const Color(0xFF0A84FF),
          ),
          title: Text(syncing ? 'Syncing YouTube Music…' : 'Sync Library'),
          subtitle: Text(_subtitle()),
          trailing: syncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  minSize: 0,
                  onPressed: () => _sync(),
                  child: const Text(
                    'Sync',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0A84FF),
                    ),
                  ),
                ),
          onTap: syncing ? null : () => _sync(),
        );
      },
    );
  }
}
