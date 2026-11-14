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
import 'package:material_ui/material_ui.dart' show Colors, Theme, Material, InkWell;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/screens/settings/settings_subpages.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF8E8E93);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n?.settings ?? 'Settings',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FluentMusic 1.4.0 · liquid glass edition',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // One coloured glass tile per section (image 10 pattern) so each
          // group is a separate card instead of one endless platter.
          _buildSettingsTile(
            context: context,
            title: 'Account',
            subtitle: 'Optional sign-in for playlist and library sync',
            icon: CupertinoIcons.person_fill,
            colors: const [Color(0xFFFF453A), Color(0xFFB3120C)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const AccountSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Listening Stats',
            subtitle: 'Top songs, artists and playback history',
            icon: CupertinoIcons.chart_bar_fill,
            colors: const [Color(0xFFFFA726), Color(0xFFC2410C)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => const ListeningStatsSettingsPage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Appearance',
            subtitle: 'Themes, layout and the Glass Lab tuner',
            icon: CupertinoIcons.paintbrush_fill,
            colors: const [Color(0xFFBF5AF2), Color(0xFF6B21A8)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => const AppearanceSettingsPage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Playback',
            subtitle: 'Audio behaviour, crossfade and background play',
            icon: CupertinoIcons.music_note_2,
            colors: const [Color(0xFF0A84FF), Color(0xFF1D4ED8)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const PlaybackSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'FluentMusic Canvas',
            subtitle: 'Sources, mobile data and cache',
            icon: CupertinoIcons.circle_grid_hex_fill,
            colors: const [Color(0xFF5E5CE6), Color(0xFF312E81)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const CanvasSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Lyrics',
            subtitle: 'Providers, translation and timed lyrics',
            icon: CupertinoIcons.doc_text_fill,
            colors: const [Color(0xFFFF375F), Color(0xFF9F1239)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const LyricsSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Content',
            subtitle: 'Language, country and recommendations',
            icon: CupertinoIcons.globe,
            colors: const [Color(0xFF32D74B), Color(0xFF15803D)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(builder: (_) => const ContentSettingsPage()),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Behaviour',
            subtitle: 'History, defaults and privacy behaviour',
            icon: CupertinoIcons.slider_horizontal_3,
            colors: const [Color(0xFFEAB308), Color(0xFF92400E)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => const BehaviorSettingsPage(),
                ),
              );
            },
          ),
          _buildSettingsTile(
            context: context,
            title: 'Android Auto',
            subtitle: 'Driving playback, browsing and data use',
            icon: CupertinoIcons.car_fill,
            colors: const [Color(0xFF30D158), Color(0xFF0F766E)],
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => const AndroidAutoSettingsPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  /// A single tinted glass tile: real shader rim + refraction, coloured body.
  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassContainer(
        useOwnLayer: true,
        quality: GlassQuality.standard,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.zero,
        shape: const LiquidRoundedSuperellipse(borderRadius: 24),
        settings: LiquidGlassSettings(
          glassColor: colors.first.withValues(alpha: 0.42),
          thickness: 24,
          blur: 4,
          refractiveIndex: 1.3,
          chromaticAberration: 0.06,
          lightIntensity: 0.7,
          saturation: 1.35,
          bodyMode: GlassBodyMode.clear,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.first.withValues(alpha: 0.55),
                      colors.last.withValues(alpha: 0.32),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -30,
              left: -10,
              child: Container(
                width: 140,
                height: 90,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      CupertinoColors.white.withValues(alpha: 0.28),
                      CupertinoColors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: CupertinoColors.white
                                .withValues(alpha: 0.28),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: CupertinoColors.white,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: CupertinoColors.white
                                    .withValues(alpha: 0.74),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_forward,
                        color: CupertinoColors.white.withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
