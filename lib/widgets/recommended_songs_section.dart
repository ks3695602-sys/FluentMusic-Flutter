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
import 'package:musify/constants/app_constants.dart';
import 'package:musify/main.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/song_bar.dart';

/// Shared titled list of recommended songs with an optional "play all" button.
class RecommendedSongsSection extends StatelessWidget {
  const RecommendedSongsSection({
    super.key,
    required this.title,
    required this.songs,
    required this.listKeyPrefix,
    this.showPlayButton = true,
    this.onAddSong,
  });

  final String title;
  final List<dynamic> songs;

  /// Scope passed to [listItemKey] so each usage keeps stable, distinct keys.
  final String listKeyPrefix;
  final bool showPlayButton;

  /// When set, each row shows an add button instead of the overflow menu.
  final void Function(Map song)? onAddSong;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playBtnColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final playBgColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.12)
        : const Color(0xFF000000).withValues(alpha: 0.08);
    final playBorderColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.18)
        : const Color(0xFF000000).withValues(alpha: 0.12);

    return Column(
      children: [
        SectionHeader(
          title: title,
          icon: FluentIcons.sparkle_24_filled,
          actionButton: showPlayButton
              ? GestureDetector(
                  onTap: () async {
                    await audioHandler.playPlaylistSong(
                      playlist: {'title': title, 'list': songs},
                      songIndex: 0,
                      shuffle: false,
                    );
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: playBgColor,
                      border: Border.all(
                        color: playBorderColor,
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: playBtnColor,
                      size: 14,
                    ),
                  ),
                )
              : null,
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: songs.length,
          padding: EdgeInsets.zero,
          separatorBuilder: (_, __) =>
              Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1, indent: 64),
          itemBuilder: (context, index) {
            final song = songs[index];
            return RepaintBoundary(
              key: listItemKey(listKeyPrefix, index, song),
              child: SongBar(
                song,
                true,
                backgroundColor: Colors.transparent,
                barPadding: const EdgeInsetsDirectional.symmetric(
                  vertical: 8,
                  horizontal: 6,
                ),
                onAdd: onAddSong != null && song is Map
                    ? () => onAddSong!(song)
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
