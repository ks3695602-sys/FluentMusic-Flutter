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
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/player_style.dart';
import 'package:musify/widgets/glass/glass_sheet_style.dart';

/// Opens the Now Playing style chooser.
///
/// The sheet applies the selection immediately and closes, so the player
/// underneath becomes the live preview. It is reachable from Appearance
/// settings and from the Now Playing overflow menu.
Future<void> showPlayerStyleSheet(BuildContext context) {
  final brightness = GlassTheme.brightnessOf(context);

  return GlassModalSheet.show<void>(
    context: context,
    detents: const {GlassSheetDetent.medium},
    settings: glassSheetSettings(context, brightness: brightness),
    builder: (sheetContext) {
      final labelColor = glassSheetLabelColor(
        sheetContext,
        brightness: brightness,
      );
      final subtitleColor = glassSheetSubtitleColor(
        sheetContext,
        brightness: brightness,
      );
      final rowColor =
          (brightness == Brightness.dark
                  ? CupertinoColors.white
                  : CupertinoColors.black)
              .withValues(alpha: brightness == Brightness.dark ? 0.09 : 0.05);

      return SafeArea(
        top: false,
        child: ValueListenableBuilder<PlayerStyle>(
          valueListenable: playerStyleSetting,
          builder: (context, selected, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Player Style',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick how Now Playing stages your music. Lyrics, '
                    'controls and gestures stay the same.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  for (final style in PlayerStyle.values) ...[
                    _PlayerStyleOption(
                      style: style,
                      selected: selected == style,
                      rowColor: rowColor,
                      labelColor: labelColor,
                      subtitleColor: subtitleColor,
                      onTap: () {
                        setPlayerStyle(style);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                    if (style != PlayerStyle.values.last)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

IconData _iconForStyle(PlayerStyle style) {
  return switch (style) {
    PlayerStyle.immersive => FluentIcons.music_note_2_24_filled,
    PlayerStyle.midnight => CupertinoIcons.moon_fill,
    PlayerStyle.vinyl => FluentIcons.cd_16_filled,
  };
}

class _PlayerStyleOption extends StatelessWidget {
  const _PlayerStyleOption({
    required this.style,
    required this.selected,
    required this.rowColor,
    required this.labelColor,
    required this.subtitleColor,
    required this.onTap,
  });

  final PlayerStyle style;
  final bool selected;
  final Color rowColor;
  final Color labelColor;
  final Color subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.16) : rowColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.55)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForStyle(style), color: accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    style.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    style.description,
                    style: TextStyle(fontSize: 12, color: subtitleColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? CupertinoIcons.check_mark_circled_solid
                  : CupertinoIcons.circle,
              color: selected
                  ? accent
                  : subtitleColor.withValues(alpha: 0.45),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
