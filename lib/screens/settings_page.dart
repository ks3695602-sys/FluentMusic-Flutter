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
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/screens/settings/settings_subpages.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _buildSquircleIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF8E8E93);
    final bgColor = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: Container(
        color: bgColor,
      ),
      appBar: canPop
          ? GlassAppBar(
              leading: buildGlassBackButton(context),
              title: Text(
                context.l10n?.settings ?? 'Settings',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: titleColor,
                ),
              ),
            )
          : null,
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          canPop ? 16 : topPadding + 16,
          16,
          40,
        ),
        children: [
          if (!canPop)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 20, top: 4),
              child: Text(
                context.l10n?.settings ?? 'Settings',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: titleColor,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          // INSET GROUPED SETTINGS PLATTER
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              // 1. Account
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.person_fill,
                  color: const Color(0xFFFF3B30),
                ),
                title: Text('Account', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Sign in and manage account sync', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const AccountSettingsPage()),
                  );
                },
              ),

              // 2. Listening Stats
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.chart_bar_fill,
                  color: const Color(0xFFFF9500),
                ),
                title: Text('Listening Stats', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Your top songs, artists, and playback history', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const ListeningStatsSettingsPage()),
                  );
                },
              ),

              // 3. Appearance & Liquid Glass
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.paintbrush_fill,
                  color: const Color(0xFFAF52DE),
                ),
                title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Themes, layout, and visual styles', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const AppearanceSettingsPage()),
                  );
                },
              ),

              // 4. Playback
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.music_note_2,
                  color: const Color(0xFF007AFF),
                ),
                title: Text('Playback', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Audio behavior, crossfade, and background', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const PlaybackSettingsPage()),
                  );
                },
              ),

              // 5. FluentMusic Canvas
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.circle_grid_hex_fill,
                  color: const Color(0xFF5856D6),
                ),
                title: Text('FluentMusic Canvas', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Sources, mobile data and cache', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const CanvasSettingsPage()),
                  );
                },
              ),

              // 6. Lyrics
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.doc_text_fill,
                  color: const Color(0xFFFF2D55),
                ),
                title: Text('Lyrics', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Lyrics providers and translation', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const LyricsSettingsPage()),
                  );
                },
              ),

              // 7. Content
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.globe,
                  color: const Color(0xFF34C759),
                ),
                title: Text('Content', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Language, country, and recommendations', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const ContentSettingsPage()),
                  );
                },
              ),

              // 8. Behavior
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.slider_horizontal_3,
                  color: const Color(0xFFFFCC00),
                ),
                title: Text('Behavior', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('History, defaults, and privacy behavior', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const BehaviorSettingsPage()),
                  );
                },
              ),

              // 9. Android Auto
              GlassListTile(
                leading: _buildSquircleIcon(
                  icon: CupertinoIcons.car_fill,
                  color: const Color(0xFF30D158),
                ),
                title: Text('Android Auto', style: TextStyle(fontWeight: FontWeight.w600, color: titleColor)),
                subtitle: Text('Driving playback, browsing and data', style: TextStyle(color: subtitleColor, fontSize: 13)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    CupertinoPageRoute(builder: (_) => const AndroidAutoSettingsPage()),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}
