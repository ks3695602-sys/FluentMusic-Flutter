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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/section_header.dart';

/// Compact two-column style "Quick Picks" rail used on the home page.
///
/// Each card is a single song with artwork, title, artist and a play badge.
/// The rail is intentionally shallow so the home page reads like Apple Music's
/// Listen Now rather than a wall of album art.
class HomeQuickPicks extends StatelessWidget {
  const HomeQuickPicks({
    super.key,
    required this.songs,
    required this.onSongTap,
  });

  final List<dynamic> songs;
  final ValueChanged<int> onSongTap;

  static const double _cardHeight = 68;

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.62)
        : const Color(0xFF8E8E93);
    final cardColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.08)
        : CupertinoColors.black.withValues(alpha: 0.05);
    final borderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : CupertinoColors.black.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: 'Quick Picks',
            icon: FluentIcons.sparkle_24_filled,
          ),
        ),
        SizedBox(
          height: _cardHeight + 8,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            clipBehavior: Clip.none,
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final song = songs[index];
              final image = song['highResImage'] ??
                  song['image'] ??
                  song['lowResImage'] ??
                  song['thumbnail'];
              final title = song['title']?.toString() ?? '';
              final artist = song['artist']?.toString() ?? '';

              return GestureDetector(
                onTap: () => onSongTap(index),
                child: Container(
                  width: 268,
                  height: _cardHeight,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 0.7),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: PlaylistArtwork(
                          playlistArtwork: image?.toString(),
                          playlistTitle: title,
                          size: 52,
                          cubeIcon: CupertinoIcons.music_note,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: subColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: CupertinoColors.white.withValues(alpha: 0.10),
                          border: Border.all(
                            color: CupertinoColors.white.withValues(alpha: 0.18),
                            width: 0.7,
                          ),
                        ),
                        child: Icon(
                          CupertinoIcons.play_fill,
                          size: 12,
                          color: titleColor,
                        ),
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
}
