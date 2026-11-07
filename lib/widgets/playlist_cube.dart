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
import 'package:musify/extensions/l10n.dart';
import 'package:musify/widgets/playlist_artwork.dart';

class PlaylistCube extends StatelessWidget {
  const PlaylistCube(
    this.playlist, {
    super.key,
    this.playlistData,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.size = 220,
    this.borderRadius = 18,
    this.showTypeLabel = true,
    this.showPlayBadge = true,
  });

  final Map? playlistData;
  final Map playlist;
  final IconData cubeIcon;
  final double size;
  final double borderRadius;
  final bool showTypeLabel;
  final bool showPlayBadge;

  static const double typeLabelOffset = 8;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          PlaylistArtwork(
            playlistArtwork: playlist['image'],
            size: size,
            cubeIcon: cubeIcon,
          ),
          if (showTypeLabel && playlist['image'] != null)
            Positioned(
              top: typeLabelOffset,
              right: typeLabelOffset,
              child: _buildLabel(context),
            ),
          if (showPlayBadge)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CupertinoColors.black.withValues(alpha: 0.55),
                  border: Border.all(
                    color: CupertinoColors.white.withValues(alpha: 0.25),
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
    );
  }

  Widget _buildLabel(BuildContext context) {
    final isAlbum = playlist['isAlbum'] == true;
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      child: Text(
        isAlbum ? context.l10n!.album : context.l10n!.playlist,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
