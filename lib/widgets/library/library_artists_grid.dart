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

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/artist_service.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:musify/widgets/section_header.dart';

/// Circular artist wall for the Library tab.
///
/// Shows the first 8 artists and can expand in place, which keeps the library
/// page tidy no matter how many artists a listener follows.
class LibraryArtistsGrid extends StatefulWidget {
  const LibraryArtistsGrid({
    super.key,
    required this.artists,
    required this.onArtistTap,
    this.collapsedCount = 8,
  });

  final List<Map> artists;
  final ValueChanged<Map> onArtistTap;
  final int collapsedCount;

  @override
  State<LibraryArtistsGrid> createState() => _LibraryArtistsGridState();
}

class _LibraryArtistsGridState extends State<LibraryArtistsGrid> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.artists.isEmpty) return const SizedBox.shrink();

    final visible = _expanded
        ? widget.artists
        : widget.artists.take(widget.collapsedCount).toList();
    final canExpand = widget.artists.length > widget.collapsedCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.62)
        : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: context.l10n?.artists ?? 'Artists',
          icon: FluentIcons.person_24_filled,
          actionButton: canExpand
              ? GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Text(
                      _expanded
                          ? 'Show less'
                          : 'Show all (${widget.artists.length})',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 340 ? 4 : 3;
            const spacing = 12.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            final avatarSize = itemWidth.clamp(52.0, 82.0);

            return Wrap(
              spacing: spacing,
              runSpacing: 16,
              children: <Widget>[
                for (final artist in visible)
                  SizedBox(
                    width: itemWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onArtistTap(artist),
                      child: Column(
                        children: <Widget>[
                          Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? CupertinoColors.white.withValues(alpha: 0.08)
                                  : CupertinoColors.black.withValues(
                                      alpha: 0.05,
                                    ),
                              border: Border.all(
                                color: isDark
                                    ? CupertinoColors.white.withValues(
                                        alpha: 0.14,
                                      )
                                    : CupertinoColors.black.withValues(
                                        alpha: 0.08,
                                      ),
                                width: 0.8,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _ArtistAvatar(
                              imageUrl: normalizeArtistThumbnailUrl(
                                artist['image']?.toString(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            normalizeArtistDisplayTitle(
                              artist['title']?.toString() ?? '',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            context.l10n?.artist ?? 'Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: subColor, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ArtistAvatar extends StatelessWidget {
  const _ArtistAvatar({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) return const _ArtistFallback();
    return Image(
      image: ArtworkProvider.get(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _ArtistFallback(),
    );
  }
}

class _ArtistFallback extends StatelessWidget {
  const _ArtistFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0x332C2C2E),
      child: Icon(
        FluentIcons.person_24_filled,
        size: 30,
        color: Color(0x99FFFFFF),
      ),
    );
  }
}
