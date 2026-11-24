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
import 'package:musify/services/artist_service.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/widgets/section_header.dart';

/// Horizontal rail of circular artist portraits for the home page.
///
/// Artists come after the song rails by design: songs first, artists later.
class HomeArtistsRail extends StatelessWidget {
  const HomeArtistsRail({
    super.key,
    required this.artists,
    required this.onArtistTap,
  });

  final List<Map> artists;
  final ValueChanged<int> onArtistTap;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.62)
        : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SectionHeader(
            title: context.l10n?.artists ?? 'Artists',
            icon: FluentIcons.person_24_filled,
          ),
        ),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.none,
            itemCount: artists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final artist = artists[index];
              final name = normalizeArtistDisplayTitle(
                artist['title']?.toString() ?? '',
              );
              final image = normalizeArtistThumbnailUrl(
                artist['image']?.toString(),
              );

              return GestureDetector(
                onTap: () => onArtistTap(index),
                child: SizedBox(
                  width: 90,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? CupertinoColors.white.withValues(alpha: 0.08)
                              : CupertinoColors.black.withValues(alpha: 0.05),
                          border: Border.all(
                            color: isDark
                                ? CupertinoColors.white
                                    .withValues(alpha: 0.14)
                                : CupertinoColors.black
                                    .withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: image != null && image.isNotEmpty
                            ? Image(
                                image: ArtworkProvider.get(image),
                                width: 86,
                                height: 86,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const _Fallback(),
                              )
                            : const _Fallback(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        context.l10n?.artist ?? 'Artist',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subColor, fontSize: 11),
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

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x332C2C2E),
      child: Icon(
        FluentIcons.person_24_filled,
        size: 34,
        color: Color(0x99FFFFFF),
      ),
    );
  }
}
