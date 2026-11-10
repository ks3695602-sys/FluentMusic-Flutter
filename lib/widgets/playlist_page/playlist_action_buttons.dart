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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/extensions/l10n.dart';

/// Apple Music iOS 26 Playlist Action Trio: Frosted Shuffle + Solid White Play Pill + Frosted Add (+).
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.onAdd,
    this.isLoading = false,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final VoidCallback? onAdd;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Frosted Shuffle Circle
          GlassIconButton(
            icon: const Icon(
              CupertinoIcons.shuffle,
              color: CupertinoColors.white,
              size: 20,
            ),
            onPressed: isLoading ? null : () => onShuffle(),
          ),

          const SizedBox(width: 16),

          // 2. Solid White Play Pill (Centerpiece)
          GlassButton.custom(
            onTap: isLoading ? () {} : onPlay,
            height: 48,
            width: 144,
            shape: const LiquidRoundedRectangle(borderRadius: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const CupertinoActivityIndicator(
                    color: CupertinoColors.white,
                  )
                else ...[
                  const Icon(
                    CupertinoIcons.play_fill,
                    color: CupertinoColors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n?.play ?? 'Play',
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 3. Frosted Add (+) Circle
          GlassIconButton(
            icon: const Icon(
              CupertinoIcons.plus,
              color: CupertinoColors.white,
              size: 22,
            ),
            onPressed: onAdd ?? () {},
          ),
        ],
      ),
    );
  }
}
