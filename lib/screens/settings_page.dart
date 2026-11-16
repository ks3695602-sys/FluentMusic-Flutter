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
import 'package:flutter/material.dart' show Theme;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/screens/settings/account_page.dart';
import 'package:musify/screens/settings/settings_subpages.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.6)
        : const Color(0xFF8E8E93);
    final topPadding = MediaQuery.paddingOf(context).top;

    void open(Widget page) {
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(builder: (_) => page),
      );
    }

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, topPadding + 18, 16, 28),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n?.settings ?? 'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'FluentMusic 1.5.2 · iOS 27 glass edition',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          _SettingsSection(
            header: 'Your stuff',
            children: [
              _SettingsTile(
                title: 'Account',
                subtitle: 'Optional sign-in for playlist and library sync',
                icon: CupertinoIcons.person_fill,
                tint: const Color(0xFFFF453A),
                onTap: () => open(const AccountSettingsPage()),
              ),
              _SettingsTile(
                title: 'Listening Stats',
                subtitle: 'Top songs, artists and playback history',
                icon: CupertinoIcons.chart_bar_fill,
                tint: const Color(0xFFFF9F0A),
                onTap: () => open(const ListeningStatsSettingsPage()),
              ),
            ],
          ),

          _SettingsSection(
            header: 'Look & sound',
            children: [
              _SettingsTile(
                title: 'Appearance',
                subtitle: 'Themes, layout and the Glass Lab tuner',
                icon: CupertinoIcons.paintbrush_fill,
                tint: const Color(0xFFBF5AF2),
                onTap: () => open(const AppearanceSettingsPage()),
              ),
              _SettingsTile(
                title: 'Playback',
                subtitle: 'Audio behaviour, crossfade and background play',
                icon: CupertinoIcons.music_note_2,
                tint: const Color(0xFF0A84FF),
                onTap: () => open(const PlaybackSettingsPage()),
              ),
              _SettingsTile(
                title: 'FluentMusic Canvas',
                subtitle: 'Sources, mobile data and cache',
                icon: CupertinoIcons.circle_grid_hex_fill,
                tint: const Color(0xFF5E5CE6),
                onTap: () => open(const CanvasSettingsPage()),
              ),
              _SettingsTile(
                title: 'Lyrics',
                subtitle: 'Providers, translation and timed lyrics',
                icon: CupertinoIcons.doc_text_fill,
                tint: const Color(0xFFFF375F),
                onTap: () => open(const LyricsSettingsPage()),
              ),
            ],
          ),

          _SettingsSection(
            header: 'Preferences',
            children: [
              _SettingsTile(
                title: 'Content',
                subtitle: 'Language, country and recommendations',
                icon: CupertinoIcons.globe,
                tint: const Color(0xFF32D74B),
                onTap: () => open(const ContentSettingsPage()),
              ),
              _SettingsTile(
                title: 'Behaviour',
                subtitle: 'History, defaults and privacy behaviour',
                icon: CupertinoIcons.slider_horizontal_3,
                tint: const Color(0xFFEAB308),
                onTap: () => open(const BehaviorSettingsPage()),
              ),
              _SettingsTile(
                title: 'Android Auto',
                subtitle: 'Driving playback, browsing and data use',
                icon: CupertinoIcons.car_fill,
                tint: const Color(0xFF30D158),
                onTap: () => open(const AndroidAutoSettingsPage()),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Center(
            child: Text(
              'v1.5.2 (16) · built with an unhealthy amount of glass',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: subtitleColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

/// One iOS inset-grouped card. Solid surfaces keep the nested pages and the
/// root page visually identical, and stop refractive glass stacking on glass.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.header, required this.children});

  final String header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      margin: const EdgeInsets.only(bottom: 14),
      dividerIndent: 58,
      header: Text(
        header.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.7,
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.48)
              : const Color(0xFF6C6C70),
        ),
      ),
      children: children,
    );
  }
}

/// A single row inside a [_SettingsSection]. Uses [GlassListTile] rather than a
/// nested [GlassContainer] so the row never paints a second glass layer.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassListTile(
      onTap: onTap,
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: isDark ? 0.24 : 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 19, color: tint),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: isDark ? CupertinoColors.white : const Color(0xFF1C1C1E),
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: isDark
              ? CupertinoColors.white.withValues(alpha: 0.55)
              : const Color(0xFF6C6C70),
        ),
      ),
      trailing: Icon(
        CupertinoIcons.chevron_forward,
        size: 15,
        color: isDark
            ? CupertinoColors.white.withValues(alpha: 0.35)
            : const Color(0xFFC7C7CC),
      ),
    );
  }
}
