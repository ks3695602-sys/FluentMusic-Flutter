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
import 'package:musify/widgets/playlist_artwork.dart';
import 'package:musify/widgets/section_header.dart';

/// Colourful two-column "Quick Picks" grid.
///
/// The old rail was a 68 px strip; this version gives every pick a big
/// gradient card with 52 px artwork, so Home actually fills the screen before
/// the dock gets a chance to collapse.
class HomeQuickPicks extends StatelessWidget {
  const HomeQuickPicks({
    super.key,
    required this.songs,
    required this.onSongTap,
  });

  final List<dynamic> songs;
  final ValueChanged<int> onSongTap;

  static const double _cardHeight = 78;

  static const List<List<Color>> _palettes = [
    [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
    [Color(0xFF1C1C1E), Color(0xFF161618)],
    [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
    [Color(0xFF1C1C1E), Color(0xFF1A1A1C)],
    [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
    [Color(0xFF1C1C1E), Color(0xFF161618)],
  ];

  @override
  Widget build(BuildContext context) {
    if (songs.isEmpty) return const SizedBox.shrink();

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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var row = 0; row < songs.length; row += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: _card(songs[row], row)),
                      const SizedBox(width: 10),
                      if (row + 1 < songs.length)
                        Expanded(child: _card(songs[row + 1], row + 1))
                      else
                        const Spacer(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _card(dynamic song, int index) {
    final image =
        song['highResImage'] ?? song['image'] ?? song['lowResImage'];
    final title = song['title']?.toString() ?? '';
    final artist = song['artist']?.toString() ?? '';
    final palette = _palettes[index % _palettes.length];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onSongTap(index),
      child: Container(
        height: _cardHeight,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.first.withValues(alpha: 0.28),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PlaylistArtwork(
                playlistArtwork: image?.toString(),
                playlistTitle: title,
                size: 58,
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
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: CupertinoColors.white.withValues(alpha: 0.78),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CupertinoColors.white.withValues(alpha: 0.18),
                border: Border.all(
                  color: CupertinoColors.white.withValues(alpha: 0.30),
                  width: 0.7,
                ),
              ),
              child: const Icon(
                CupertinoIcons.play_fill,
                size: 12,
                color: CupertinoColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
