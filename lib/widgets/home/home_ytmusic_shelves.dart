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
import 'package:musify/services/ytmusic_library_service.dart';
import 'package:musify/services/ytmusic_library_store.dart';
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/playlist_cube.dart';
import 'package:musify/widgets/section_header.dart';

/// Account-powered rails from `FEmusic_home` (Listen again, Speed dial,
/// Forgotten favourites, …). Renders nothing when the user is signed out or
/// has not synced yet.
class HomeYtMusicShelves extends StatelessWidget {
  const HomeYtMusicShelves({super.key});

  static const double _cardSize = 160;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<YtMusicShelf>>(
      valueListenable: ytMusicHomeShelves,
      builder: (context, shelves, _) {
        if (shelves.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final shelf in shelves.take(5))
              _Shelf(shelf: shelf, cardSize: _cardSize),
          ],
        );
      },
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.shelf, required this.cardSize});

  final YtMusicShelf shelf;
  final double cardSize;

  @override
  Widget build(BuildContext context) {
    final items = shelf.items.take(12).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: shelf.title,
            icon: FluentIcons.sparkle_24_filled,
          ),
        ),
        SizedBox(
          height: cardSize + 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final title = item['title']?.toString() ?? '';
              final image =
                  item['highResImage'] ?? item['image'] ?? item['lowResImage'];

              if (item['kind'] == 'song') {
                final songs = shelf.items
                    .where((entry) => entry['kind'] == 'song')
                    .toList();
                final songIndex = songs.indexWhere(
                  (entry) => entry['ytid'] == item['ytid'],
                );
                return SizedBox(
                  width: cardSize,
                  child: GestureDetector(
                    onTap: () => _play(songs, songIndex < 0 ? 0 : songIndex),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              PlaylistArtwork(
                                playlistArtwork: image?.toString(),
                                playlistTitle: title,
                                size: cardSize,
                                cubeIcon: CupertinoIcons.music_note,
                              ),
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: CupertinoColors.black.withValues(
                                      alpha: 0.52,
                                    ),
                                    border: Border.all(
                                      color: CupertinoColors.white.withValues(
                                        alpha: 0.25,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.play_fill,
                                    color: CupertinoColors.white,
                                    size: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['artist']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SizedBox(
                width: cardSize,
                child: GestureDetector(
                  onTap: () => context.push('/home/playlist/${item['ytid']}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlaylistCube(
                        item,
                        size: cardSize,
                        borderRadius: 20,
                        showTypeLabel: false,
                        showPlayBadge: true,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['author']?.toString() ??
                            (item['isAlbum'] == true ? 'Album' : 'Playlist'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _play(List<Map<String, dynamic>> songs, int index) async {
    if (songs.isEmpty) return;
    await audioHandler.playPlaylistSong(
      playlist: {'title': shelf.title, 'list': songs},
      songIndex: index,
    );
  }
}
