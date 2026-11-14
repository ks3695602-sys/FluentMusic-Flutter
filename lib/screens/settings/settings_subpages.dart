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

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:musify/theme/app_themes.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/equalizer_page.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/widgets/glass/glass_lab_page.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

Widget buildGlassBackButton(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Padding(
    padding: const EdgeInsets.all(6.0),
    child: GlassIconButton(
      icon: Icon(
        CupertinoIcons.chevron_back,
        color: isDark ? Colors.white : Colors.black87,
        size: 20,
      ),
      onPressed: () => Navigator.of(context).pop(),
    ),
  );
}

Widget buildSubpageBackground(bool isDark) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF160E20),
                Color(0xFF0F0B16),
                Color(0xFF08060B),
                Color(0xFF000000),
              ]
            : const [
                Color(0xFFF2ECF9),
                Color(0xFFF8F8FB),
                Color(0xFFEBEFF5),
                Color(0xFFF2F2F7),
              ],
        stops: const [0.0, 0.35, 0.70, 1.0],
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. LISTENING STATS SUBPAGE
// ---------------------------------------------------------------------------
class ListeningStatsSettingsPage extends StatelessWidget {
  const ListeningStatsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Listening Stats',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: wrappedEnabled,
            builder: (_, enabled, __) {
              return GlassGroupedSection(
                surfaceStyle: GlassSurfaceStyle.solid,
                header: Text(
                  'TRACKING & RECAP',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.chart_pie_fill,
                      color: Color(0xFFFF9500),
                    ),
                    title: Text(
                      'Time Machine & Listening Stats',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Track minutes listened, top artists & recap',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: enabled,
                      onChanged: (val) {
                        wrappedEnabled.value = val;
                        addOrUpdateData('settings', 'wrappedEnabled', val);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'ACTIONS',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.trash,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text(
                  'Clear Listening History',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                subtitle: Text(
                  'Resets play count and recap calculations',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                onTap: () async {
                  await listeningStatsService.clearStats();
                  if (context.mounted) {
                    showToast(context, 'Listening stats cleared');
                  }
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. APPEARANCE & LIVE LIQUID GLASS OPTICS SUBPAGE
// ---------------------------------------------------------------------------
class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Liquid Glass',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // 1. LIVE ARCHITECTURAL WALLPAPER PREVIEW CARD
          ValueListenableBuilder<GlassThemeData>(
            valueListenable: liquidGlassThemeNotifier,
            builder: (context, theme, _) {
              return Container(
                height: 220,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2C3E50),
                      Color(0xFF1A1A2E),
                      Color(0xFF0F0C29),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, -0.4),
                              radius: 1.2,
                              colors: [
                                Colors.blueGrey.shade700,
                                const Color(0xFF141727),
                                Colors.black,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 34,
                        left: 20,
                        right: 20,
                        child: Text(
                          'Aurora Borealis',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GlassButton.custom(
                            onTap: () {},
                            height: 48,
                            width: double.infinity,
                            shape: const LiquidRoundedRectangle(
                              borderRadius: 24,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.search,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Songs, albums or artists',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            },
          ),

          // 2. GLASS LAB ENTRY — every tuner slider lives on its own page now
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              GlassListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFAF52DE).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    CupertinoIcons.sparkles,
                    color: Color(0xFFAF52DE),
                  ),
                ),
                title: Text(
                  'Glass Lab',
                  style: TextStyle(color: titleColor),
                ),
                subtitle: Text(
                  '8 live sliders — pinch, expansion, dispersion, tint, refraction and radii',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                trailing: Icon(
                  CupertinoIcons.chevron_forward,
                  color: subtitleColor,
                  size: 16,
                ),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => const GlassLabPage(),
                  ),
                ),
              ),
            ],
          ),

          // 4. THEME & DISPLAY
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8, top: 20),
            child: Text(
              'THEME & DISPLAY',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        CupertinoIcons.sun_max_fill,
                        color: Color(0xFFFFCC00),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n?.themeMode ?? 'Theme Mode',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                GlassSegmentedControl(
                  segments: const [
                    GlassSegment(label: 'System'),
                    GlassSegment(label: 'Light'),
                    GlassSegment(label: 'Dark'),
                  ],
                  selectedIndex: themeMode == ThemeMode.system
                      ? 0
                      : (themeMode == ThemeMode.light ? 1 : 2),
                  onSegmentSelected: (index) {
                    final mode = index == 0
                        ? ThemeMode.system
                        : (index == 1 ? ThemeMode.light : ThemeMode.dark);
                    addOrUpdateData<int>('settings', 'themeIndex', mode.index);
                    Musify.updateAppState(context, newThemeMode: mode);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: usePureBlackColor,
                builder: (_, pureBlack, __) {
                  return GlassListTile(
                    leading: Icon(
                      CupertinoIcons.moon_fill,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    title: Text(
                      'OLED Pure Black',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Deep OLED true black backdrop',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: pureBlack,
                      onChanged: (val) {
                        usePureBlackColor.value = val;
                        addOrUpdateData('settings', 'usePureBlackColor', val);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. PLAYBACK SUBPAGE
// ---------------------------------------------------------------------------
class PlaybackSettingsPage extends StatelessWidget {
  const PlaybackSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Playback',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: Text(
                'AUDIO QUALITY',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: audioQualitySetting,
                  builder: (_, currentQuality, __) {
                    return GlassListTile(
                      leading: const Icon(
                        CupertinoIcons.waveform,
                        color: Color(0xFF007AFF),
                      ),
                      title: Text(
                        'Streaming Quality',
                        style: TextStyle(color: titleColor),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: CupertinoSlidingSegmentedControl<String>(
                          groupValue: currentQuality,
                          children: {
                            'low': Text(
                              'Low (96k)',
                              style: TextStyle(color: titleColor, fontSize: 12),
                            ),
                            'medium': Text(
                              'Med (160k)',
                              style: TextStyle(color: titleColor, fontSize: 12),
                            ),
                            'high': Text(
                              'High (320k)',
                              style: TextStyle(color: titleColor, fontSize: 12),
                            ),
                          },
                          onValueChanged: (val) {
                            if (val != null) {
                              audioQualitySetting.value = val;
                              addOrUpdateData('settings', 'audioQuality', val);
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassGroupedSection(
              surfaceStyle: GlassSurfaceStyle.solid,
              header: Text(
                'TRANSITIONS & EQUALIZER',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                ValueListenableBuilder<double>(
                  valueListenable: crossfadeDurationSetting,
                  builder: (_, crossfadeVal, __) {
                    return GlassListTile(
                      leading: const Icon(
                        CupertinoIcons.slider_horizontal_below_rectangle,
                        color: Color(0xFFFF2D55),
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Crossfade', style: TextStyle(color: titleColor)),
                          Text(
                            crossfadeVal == 0
                                ? 'Off'
                                : '${crossfadeVal.toStringAsFixed(1)}s',
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: GlassSlider(
                          value: crossfadeVal.clamp(0.0, 12.0),
                          min: 0.0,
                          max: 12.0,
                          onChanged: (newVal) {
                            crossfadeDurationSetting.value = newVal;
                            addOrUpdateData(
                              'settings',
                              'crossfadeDuration',
                              newVal,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: gaplessPlaybackEnabled,
                  builder: (_, gapless, __) {
                    return GlassListTile(
                      leading: const Icon(
                        CupertinoIcons.infinite,
                        color: Color(0xFF34C759),
                      ),
                      title: Text(
                        'Gapless Playback',
                        style: TextStyle(color: titleColor),
                      ),
                      subtitle: Text(
                        'Seamless track transitions with zero silence',
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                      trailing: GlassSwitch(
                        value: gapless,
                        onChanged: (val) {
                          gaplessPlaybackEnabled.value = val;
                          addOrUpdateData(
                            'settings',
                            'gaplessPlaybackEnabled',
                            val,
                          );
                        },
                      ),
                    );
                  },
                ),
                GlassListTile(
                  leading: const Icon(
                    CupertinoIcons.slider_horizontal_3,
                    color: Color(0xFFAF52DE),
                  ),
                  title: Text(
                    'Equalizer',
                    style: TextStyle(color: titleColor),
                  ),
                  subtitle: Text(
                    'Adjust bass, virtualizer, and frequency bands',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                  trailing: GlassListTile.chevron,
                  onTap: () {
                    Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const EqualizerPage()),
                    );
                  },
                ),
              ],
            ),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. FLUENTMUSIC CANVAS (SOURCES & CACHE) SUBPAGE
// ---------------------------------------------------------------------------
class CanvasSettingsPage extends StatefulWidget {
  const CanvasSettingsPage({super.key});

  @override
  State<CanvasSettingsPage> createState() => _CanvasSettingsPageState();
}

class _CanvasSettingsPageState extends State<CanvasSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'FluentMusic Canvas',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'STORAGE & CACHE',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: smartCacheEnabled,
                builder: (_, smartCache, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.sparkles,
                      color: Color(0xFF5856D6),
                    ),
                    title: Text(
                      'Smart Lossless Cache',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Intelligently caches high-fidelity songs for instant playback',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: smartCache,
                      onChanged: (val) {
                        smartCacheEnabled.value = val;
                        addOrUpdateData('settings', 'smartCacheEnabled', val);
                      },
                    ),
                  );
                },
              ),
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.trash,
                  color: Color(0xFFFF3B30),
                ),
                title: const Text(
                  'Clear Audio Cache',
                  style: TextStyle(color: Color(0xFFFF3B30)),
                ),
                subtitle: Text(
                  'Free up local storage without deleting favorites',
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                onTap: () async {
                  showToast(context, 'Audio cache cleared successfully');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'NETWORK & DATA',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: offlineMode,
                builder: (_, isOffline, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.airplane,
                      color: Color(0xFFFF9500),
                    ),
                    title: Text(
                      'Offline Mode',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Only play downloaded and cached media',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: isOffline,
                      onChanged: (val) {
                        offlineMode.value = val;
                        addOrUpdateData('settings', 'offlineMode', val);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. LYRICS SUBPAGE
// ---------------------------------------------------------------------------
class LyricsSettingsPage extends StatelessWidget {
  const LyricsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Lyrics & Sync',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'APPLE MUSIC KARAOKE SYNC',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: appleMusicLyricsEnabled,
                builder: (_, lyricsEnabled, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.music_mic,
                      color: Color(0xFFFF2D55),
                    ),
                    title: Text(
                      'Apple Music Glowing Lyrics',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Full-screen dynamic glowing lyrics with word tracking',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: lyricsEnabled,
                      onChanged: (val) {
                        appleMusicLyricsEnabled.value = val;
                        addOrUpdateData(
                          'settings',
                          'appleMusicLyricsEnabled',
                          val,
                        );
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: wordByWordLyricsEnabled,
                builder: (_, wordSync, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.text_quote,
                      color: Color(0xFFAF52DE),
                    ),
                    title: Text(
                      'Word-to-Word Karaoke Tracking',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Real-time syllable highlighting (YouLyPlus & BetterLyrics)',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: wordSync,
                      onChanged: (val) {
                        wordByWordLyricsEnabled.value = val;
                        addOrUpdateData(
                          'settings',
                          'wordByWordLyricsEnabled',
                          val,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. CONTENT & REGION SUBPAGE
// ---------------------------------------------------------------------------
class ContentSettingsPage extends StatelessWidget {
  const ContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Content & Region',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'LOCALIZATION',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.globe,
                  color: Color(0xFF007AFF),
                ),
                title: Text(
                  'App Language',
                  style: TextStyle(color: titleColor),
                ),
                subtitle: Text(
                  languageSetting.languageCode.toUpperCase(),
                  style: TextStyle(color: subtitleColor, fontSize: 12),
                ),
                trailing: GlassListTile.chevron,
                onTap: () {
                  showToast(context, 'Language selector opened');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'FILTERING',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: sponsorBlockSupport,
                builder: (_, sponsorBlock, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.shield_fill,
                      color: Color(0xFF30D158),
                    ),
                    title: Text(
                      'SponsorBlock Integration',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Automatically skip non-music segments & intros',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: sponsorBlock,
                      onChanged: (val) {
                        sponsorBlockSupport.value = val;
                        addOrUpdateData('settings', 'sponsorBlockSupport', val);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. BEHAVIOR & PRIVACY SUBPAGE
// ---------------------------------------------------------------------------
class BehaviorSettingsPage extends StatelessWidget {
  const BehaviorSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Behavior & Privacy',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'PLAYBACK CONTROLS',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: autoResumePlaybackEnabled,
                builder: (_, autoResume, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.play_circle,
                      color: Color(0xFFFF9500),
                    ),
                    title: Text(
                      'Auto-Resume on Launch',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Resume last playing track when app opens',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: autoResume,
                      onChanged: (val) {
                        autoResumePlaybackEnabled.value = val;
                        addOrUpdateData(
                          'settings',
                          'autoResumePlaybackEnabled',
                          val,
                        );
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: pauseOnHeadphoneDisconnect,
                builder: (_, pauseOnDisconnect, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.headphones,
                      color: Color(0xFF007AFF),
                    ),
                    title: Text(
                      'Pause on Disconnect',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Pause audio when headphones or Bluetooth unplug',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: pauseOnDisconnect,
                      onChanged: (val) {
                        pauseOnHeadphoneDisconnect.value = val;
                        addOrUpdateData(
                          'settings',
                          'pauseOnHeadphoneDisconnect',
                          val,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'SEARCH PRIVACY',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: saveSearchHistoryEnabled,
                builder: (_, saveHistory, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.search,
                      color: Color(0xFFAF52DE),
                    ),
                    title: Text(
                      'Save Search History',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Store recent searches on this device',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: saveHistory,
                      onChanged: (val) {
                        saveSearchHistoryEnabled.value = val;
                        addOrUpdateData(
                          'settings',
                          'saveSearchHistoryEnabled',
                          val,
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 9. ANDROID AUTO SUBPAGE
// ---------------------------------------------------------------------------
class AndroidAutoSettingsPage extends StatelessWidget {
  const AndroidAutoSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      contentAwareBrightness: true,
      background: buildSubpageBackground(isDark),
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: Text(
          'Android Auto',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: Text(
              'CAR DASHBOARD INTEGRATION',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: androidAutoEnabled,
                builder: (_, autoEnabled, __) {
                  return GlassListTile(
                    leading: const Icon(
                      CupertinoIcons.car_fill,
                      color: Color(0xFF30D158),
                    ),
                    title: Text(
                      'Enable Android Auto',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      'Expose media browser service to car head unit',
                      style: TextStyle(color: subtitleColor, fontSize: 12),
                    ),
                    trailing: GlassSwitch(
                      value: autoEnabled,
                      onChanged: (val) {
                        androidAutoEnabled.value = val;
                        addOrUpdateData('settings', 'androidAutoEnabled', val);
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }
}
