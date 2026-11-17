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
import 'package:musify/main.dart' show audioHandler;

/// Reserves room only when the dock actually carries its mini-player
/// accessory. The safe-area inset is added explicitly because the dock floats
/// over the page body instead of shrinking it.
class MiniPlayerBottomSpace extends StatelessWidget {
  const MiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: audioHandler.mediaItem,
      initialData: audioHandler.mediaItem.value,
      builder: (context, snapshot) => SizedBox(
        height: _bottomSpace(context, snapshot.data != null),
      ),
    );
  }
}

/// Sliver equivalent of [MiniPlayerBottomSpace].
class SliverMiniPlayerBottomSpace extends StatelessWidget {
  const SliverMiniPlayerBottomSpace({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: StreamBuilder(
        stream: audioHandler.mediaItem,
        initialData: audioHandler.mediaItem.value,
        builder: (context, snapshot) => SizedBox(
          height: _bottomSpace(context, snapshot.data != null),
        ),
      ),
    );
  }
}

double _bottomSpace(BuildContext context, bool hasMiniPlayer) {
  final safeBottom = MediaQuery.paddingOf(context).bottom;
  // Dock only (64 px bar + 16 px padding) without a track, dock plus the
  // 64 px accessory strip with one. Both leave a small visual gap above the
  // floating glass so the last row never touches it.
  return (hasMiniPlayer ? 150.0 : 88.0) + safeBottom;
}
