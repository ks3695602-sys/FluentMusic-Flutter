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
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.20),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(24),
              onPressed: isLoading ? null : () => onShuffle(),
              child: const Icon(
                CupertinoIcons.shuffle,
                color: CupertinoColors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // 2. Solid White Play Pill (Centerpiece)
          SizedBox(
            height: 48,
            width: 140,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(24),
              onPressed: isLoading ? null : onPlay,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const CupertinoActivityIndicator(color: CupertinoColors.black)
                  else ...[
                    const Icon(
                      CupertinoIcons.play_fill,
                      color: CupertinoColors.black,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n?.play ?? 'Play',
                      style: const TextStyle(
                        color: CupertinoColors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 14),

          // 3. Frosted Add (+) Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.white.withValues(alpha: 0.14),
              border: Border.all(
                color: CupertinoColors.white.withValues(alpha: 0.20),
                width: 0.8,
              ),
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(24),
              onPressed: onAdd ?? () {},
              child: const Icon(
                CupertinoIcons.plus,
                color: CupertinoColors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
