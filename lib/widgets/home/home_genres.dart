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
import 'package:musify/widgets/section_header.dart';

/// Colourful genre chips that launch a search for the tapped genre.
class HomeGenres extends StatelessWidget {
  const HomeGenres({
    super.key,
    required this.onGenreTap,
  });

  final ValueChanged<String> onGenreTap;

  static const List<String> genres = <String>[
    'Pop',
    'Hip-Hop',
    'Rock',
    'R&B',
    'Electronic',
    'Indie',
    'Jazz',
    'Classical',
    'Lofi',
    'Bollywood',
    'Punjabi',
    'K-Pop',
  ];

  static const List<List<Color>> _gradients = <List<Color>>[
    [Color(0xFFFF5E7E), Color(0xFFB01E4F)],
    [Color(0xFFFF9F43), Color(0xFFC0392B)],
    [Color(0xFF6C5CE7), Color(0xFF2D1B8F)],
    [Color(0xFF00B894), Color(0xFF006B5E)],
    [Color(0xFF0984E3), Color(0xFF063A6B)],
    [Color(0xFFE84393), Color(0xFF8E1B5B)],
    [Color(0xFFFDCB6E), Color(0xFFB8860B)],
    [Color(0xFF74B9FF), Color(0xFF1B4F72)],
    [Color(0xFF55EFC4), Color(0xFF0E6655)],
    [Color(0xFFFF7675), Color(0xFF922B21)],
    [Color(0xFFA29BFE), Color(0xFF4A3ABF)],
    [Color(0xFFFD79A8), Color(0xFFA61E54)],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Genres',
            icon: FluentIcons.apps_list_24_filled,
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (var i = 0; i < genres.length; i++)
                _GenreChip(
                  label: genres[i],
                  colors: _gradients[i % _gradients.length],
                  onTap: () => onGenreTap(genres[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.first.withValues(alpha: 0.9),
              colors.last.withValues(alpha: 0.7),
            ],
          ),
          border: Border.all(
            color: CupertinoColors.white.withValues(alpha: 0.22),
            width: 0.8,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.last.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: CupertinoColors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            shadows: <Shadow>[
              Shadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
