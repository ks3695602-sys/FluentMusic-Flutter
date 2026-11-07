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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';

/// Apple Music iOS 26 Play and Shuffle action pills.
class PlaylistActionButtons extends StatelessWidget {
  const PlaylistActionButtons({
    super.key,
    required this.onPlay,
    required this.onShuffle,
    this.isLoading = false,
  });

  final VoidCallback onPlay;
  final AsyncCallback onShuffle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Play Button (Solid White Pill with Black Typography)
          Expanded(
            child: SizedBox(
              height: 48,
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
          ),
          const SizedBox(width: 12),
          // Shuffle Button (Translucent Frosted Pill)
          Expanded(
            child: SizedBox(
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: CupertinoColors.white.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(24),
                  onPressed: isLoading ? null : () => onShuffle(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLoading)
                        const CupertinoActivityIndicator(color: CupertinoColors.white)
                      else ...[
                        const Icon(
                          CupertinoIcons.shuffle,
                          color: CupertinoColors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n?.shuffle ?? 'Shuffle',
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
