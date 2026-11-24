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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/listening_stats_utils.dart';

/// Big colourful "Listen Now" card at the top of Home.
///
/// Gives the page real weight before the rails start: a greeting, three live
/// library stats and a one-tap shuffle, all from data the app already has.
class HomeHero extends StatelessWidget {
  const HomeHero({super.key});

  Future<void> _shuffleLiked() async {
    final songs = userLikedSongsList.value;
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': 'Liked Songs', 'list': songs},
      songIndex: 0,
      shuffle: true,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Still awake?';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Late-night listening';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        userLikedSongsList,
        userLikedPlaylists,
        wrappedEnabled,
      ]),
      builder: (context, _) {
        final songs = userLikedSongsList.value;
        final playlists = userLikedPlaylists.value
            .where((playlist) => !isArtistPlaylist(playlist))
            .length;

        var minutes = 0;
        if (wrappedEnabled.value) {
          final monthKey = listeningStatsMonthKey(DateTime.now());
          minutes = monthDisplayMinutes(
            listeningStatsService.monthStats(monthKey),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF6D28D9),
                    Color(0xFFDB2777),
                    Color(0xFFF97316),
                  ],
                  stops: [0.0, 0.62, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Soft light blobs so the card does not read as a flat
                  // rectangle behind the text.
                  Positioned(
                    top: -46,
                    right: -28,
                    child: _Blob(size: 150, opacity: 0.20),
                  ),
                  Positioned(
                    bottom: -60,
                    left: -20,
                    child: _Blob(size: 120, opacity: 0.12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _greeting(),
                                    style: TextStyle(
                                      color: CupertinoColors.white.withValues(
                                        alpha: 0.78,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Your music, on repeat',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CupertinoColors.white.withValues(
                                  alpha: 0.18,
                                ),
                                border: Border.all(
                                  color: CupertinoColors.white.withValues(
                                    alpha: 0.35,
                                  ),
                                  width: 0.8,
                                ),
                              ),
                              child: const Icon(
                                FluentIcons.music_note_2_24_filled,
                                color: CupertinoColors.white,
                                size: 21,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _StatPill(
                              icon: FluentIcons.heart_24_filled,
                              value: '${songs.length}',
                              label: 'liked',
                            ),
                            const SizedBox(width: 8),
                            _StatPill(
                              icon: FluentIcons.library_24_regular,
                              value: '$playlists',
                              label: 'playlists',
                            ),
                            const SizedBox(width: 8),
                            _StatPill(
                              icon: FluentIcons.clock_24_regular,
                              value: minutes > 0 ? '$minutes' : '0',
                              label: 'min/mo',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                color: CupertinoColors.white,
                                pressedOpacity: 0.85,
                                onPressed: songs.isEmpty
                                    ? null
                                    : () => _shuffleLiked(),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.play_fill,
                                      size: 15,
                                      color: Color(0xFF1C1C1E),
                                    ),
                                    SizedBox(width: 7),
                                    Text(
                                      'Shuffle liked',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1C1C1E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              color: CupertinoColors.white.withValues(
                                alpha: 0.18,
                              ),
                              onPressed: () =>
                                  context.push('/home/timeMachine'),
                              child: const Text(
                                'Stats',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CupertinoColors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: CupertinoColors.black.withValues(alpha: 0.20),
          border: Border.all(
            color: CupertinoColors.white.withValues(alpha: 0.16),
            width: 0.7,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: CupertinoColors.white),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.72),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
