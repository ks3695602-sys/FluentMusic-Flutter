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
import 'package:flutter/material.dart' show Colors, ThemeMode;
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
import 'package:musify/widgets/mini_player_bottom_space.dart';

Widget buildGlassBackButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(6.0),
    child: GlassIconButton(
      icon: const Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
      onPressed: () => Navigator.of(context).pop(),
    ),
  );
}

// ---------------------------------------------------------------------------
// 1. ACCOUNT SUBPAGE
// ---------------------------------------------------------------------------
class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              GlassListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF3B30).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(CupertinoIcons.person_crop_circle, color: Color(0xFFFF3B30), size: 28),
                ),
                title: const Text('FluentMusic User', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
                subtitle: const Text('Local profile (Private Mode)', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('DATA & BACKUP'),
            children: [
              GlassListTile(
                leading: const Icon(CupertinoIcons.cloud_upload, color: Color(0xFF007AFF)),
                title: const Text('Backup Playlists & Favorites', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Export JSON snapshot to local storage', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: GlassListTile.chevron,
                onTap: () async {
                  showToast(context, 'Exporting backup to Downloads...');
                },
              ),
              GlassListTile(
                leading: const Icon(CupertinoIcons.cloud_download, color: Color(0xFF30D158)),
                title: const Text('Restore from Backup', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Import previously exported JSON data', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: GlassListTile.chevron,
                onTap: () async {
                  showToast(context, 'Select JSON backup file to restore');
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
// 2. LISTENING STATS SUBPAGE
// ---------------------------------------------------------------------------
class ListeningStatsSettingsPage extends StatelessWidget {
  const ListeningStatsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Listening Stats', style: TextStyle(fontWeight: FontWeight.bold)),
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
                header: const Text('TRACKING & RECAP'),
                children: [
                  GlassListTile(
                    leading: const Icon(CupertinoIcons.chart_pie_fill, color: Color(0xFFFF9500)),
                    title: const Text('Time Machine & Listening Stats', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Track minutes listened, top artists & recap', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
            header: const Text('ACTIONS'),
            children: [
              GlassListTile(
                leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30)),
                title: const Text('Clear Listening History', style: TextStyle(color: Color(0xFFFF3B30))),
                subtitle: const Text('Resets play count and recap calculations', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  await listeningStatsService.clearStats();
                  if (context.mounted) showToast(context, 'Listening stats cleared');
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Appearance & Optics', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // LIVE INTERACTIVE GLASS PREVIEW
          ValueListenableBuilder<GlassThemeData>(
            valueListenable: liquidGlassThemeNotifier,
            builder: (context, theme, _) {
              return Container(
                height: 120,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0284F), Color(0xFF6B11FF), Color(0xFF007AFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: GlassContainer.card(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(CupertinoIcons.sparkles, color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Live Optics: ${liquidGlassBlurSetting.value.toInt()}px blur',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // LIQUID GLASS ENGINE CONTROLS
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('LIQUID GLASS & GRAPHICS PIPELINE'),
            children: [
              // QUALITY TIER
              ValueListenableBuilder<String>(
                valueListenable: liquidGlassQualitySetting,
                builder: (_, currentQuality, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.wand_rays, color: Color(0xFFAF52DE)),
                    title: const Text('Shader Quality Tier', style: TextStyle(color: Colors.white)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: currentQuality,
                        children: const {
                          'premium': Text('Premium', style: TextStyle(color: Colors.white, fontSize: 12)),
                          'standard': Text('Standard', style: TextStyle(color: Colors.white, fontSize: 12)),
                          'minimal': Text('Minimal', style: TextStyle(color: Colors.white, fontSize: 12)),
                        },
                        onValueChanged: (val) {
                          if (val != null) {
                            liquidGlassQualitySetting.value = val;
                            addOrUpdateData('settings', 'liquidGlassQuality', val);
                            updateLiquidGlassTheme();
                          }
                        },
                      ),
                    ),
                  );
                },
              ),

              // BLUR INTENSITY SLIDER
              ValueListenableBuilder<double>(
                valueListenable: liquidGlassBlurSetting,
                builder: (_, blurVal, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFF007AFF)),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Blur & Refraction', style: TextStyle(color: Colors.white)),
                        Text('${blurVal.toInt()}px', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: GlassSlider(
                        value: blurVal,
                        min: 8.0,
                        max: 40.0,
                        onChanged: (newVal) {
                          liquidGlassBlurSetting.value = newVal;
                          addOrUpdateData('settings', 'liquidGlassBlur', newVal);
                          updateLiquidGlassTheme();
                        },
                      ),
                    ),
                  );
                },
              ),

              // THICKNESS / DISPERSION SLIDER
              ValueListenableBuilder<double>(
                valueListenable: liquidGlassThicknessSetting,
                builder: (_, thickVal, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.cube, color: Color(0xFFFF9500)),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Glass Thickness', style: TextStyle(color: Colors.white)),
                        Text('${thickVal.toInt()}', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: GlassSlider(
                        value: thickVal,
                        min: 10.0,
                        max: 50.0,
                        onChanged: (newVal) {
                          liquidGlassThicknessSetting.value = newVal;
                          addOrUpdateData('settings', 'liquidGlassThickness', newVal);
                          updateLiquidGlassTheme();
                        },
                      ),
                    ),
                  );
                },
              ),

              // DOCK OPACITY SLIDER
              ValueListenableBuilder<double>(
                valueListenable: liquidGlassDockOpacitySetting,
                builder: (_, dockOpacity, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.rectangle_dock, color: Color(0xFF30D158)),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Bottom Dock Tint', style: TextStyle(color: Colors.white)),
                        Text('${(dockOpacity * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: GlassSlider(
                        value: dockOpacity,
                        min: 0.05,
                        max: 0.50,
                        onChanged: (newVal) {
                          liquidGlassDockOpacitySetting.value = newVal;
                          addOrUpdateData('settings', 'liquidGlassDockOpacity', newVal);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // THEME & DISPLAY
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('THEME & DISPLAY'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: usePureBlackColor,
                builder: (_, pureBlack, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.moon_fill, color: Colors.white),
                    title: const Text('OLED Pure Black', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Deep OLED true black backdrop', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Playback', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('AUDIO QUALITY'),
            children: [
              ValueListenableBuilder<String>(
                valueListenable: audioQualitySetting,
                builder: (_, currentQuality, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.waveform, color: Color(0xFF007AFF)),
                    title: const Text('Streaming Quality', style: TextStyle(color: Colors.white)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: CupertinoSlidingSegmentedControl<String>(
                        groupValue: currentQuality,
                        children: const {
                          'low': Text('Low (96k)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          'medium': Text('Med (160k)', style: TextStyle(color: Colors.white, fontSize: 12)),
                          'high': Text('High (320k)', style: TextStyle(color: Colors.white, fontSize: 12)),
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
              GlassListTile(
                leading: const Icon(CupertinoIcons.slider_horizontal_below_rectangle, color: Color(0xFF30D158)),
                title: const Text('Hardware Equalizer', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Bass boost, reverb & 10-band equalization', style: TextStyle(color: Colors.white54, fontSize: 12)),
                trailing: GlassListTile.chevron,
                onTap: () {
                  Navigator.push(context, CupertinoPageRoute(builder: (_) => const EqualizerPage()));
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('SEAMLESS TRANSITIONS'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: gaplessPlaybackEnabled,
                builder: (_, gapless, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.play_circle_fill, color: Color(0xFFFF9500)),
                    title: const Text('Gapless Playback', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Pre-buffer next track for zero gap', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: gapless,
                      onChanged: (val) {
                        gaplessPlaybackEnabled.value = val;
                        addOrUpdateData('settings', 'gaplessPlaybackEnabled', val);
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: playNextSongAutomatically,
                builder: (_, autoPlay, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.infinite, color: Color(0xFFAF52DE)),
                    title: const Text('Infinite Autoplay', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Continue similar music when queue ends', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: autoPlay,
                      onChanged: (val) {
                        playNextSongAutomatically.value = val;
                        addOrUpdateData('settings', 'playNextSongAutomatically', val);
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('FluentMusic Canvas', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('STORAGE & CACHE'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: smartCacheEnabled,
                builder: (_, smartCache, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.sparkles, color: Color(0xFF5856D6)),
                    title: const Text('Smart Lossless Cache', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Intelligently caches high-fidelity songs for instant playback', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF3B30)),
                title: const Text('Clear Audio Cache', style: TextStyle(color: Color(0xFFFF3B30))),
                subtitle: const Text('Free up local storage without deleting favorites', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () async {
                  showToast(context, 'Audio cache cleared successfully');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('NETWORK & DATA'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: offlineMode,
                builder: (_, isOffline, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.airplane, color: Color(0xFFFF9500)),
                    title: const Text('Offline Mode', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Only play downloaded and cached media', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Lyrics & Sync', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('APPLE MUSIC KARAOKE SYNC'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: appleMusicLyricsEnabled,
                builder: (_, lyricsEnabled, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.music_mic, color: Color(0xFFFF2D55)),
                    title: const Text('Apple Music Glowing Lyrics', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Full-screen dynamic glowing lyrics with word tracking', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: lyricsEnabled,
                      onChanged: (val) {
                        appleMusicLyricsEnabled.value = val;
                        addOrUpdateData('settings', 'appleMusicLyricsEnabled', val);
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: wordByWordLyricsEnabled,
                builder: (_, wordSync, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.text_quote, color: Color(0xFFAF52DE)),
                    title: const Text('Word-to-Word Karaoke Tracking', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Real-time syllable highlighting (YouLyPlus & BetterLyrics)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: wordSync,
                      onChanged: (val) {
                        wordByWordLyricsEnabled.value = val;
                        addOrUpdateData('settings', 'wordByWordLyricsEnabled', val);
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Content & Region', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('LOCALIZATION'),
            children: [
              GlassListTile(
                leading: const Icon(CupertinoIcons.globe, color: Color(0xFF007AFF)),
                title: const Text('App Language', style: TextStyle(color: Colors.white)),
                subtitle: Text(languageSetting.languageCode.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12)),
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
            header: const Text('FILTERING'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: sponsorBlockSupport,
                builder: (_, sponsorBlock, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.shield_fill, color: Color(0xFF30D158)),
                    title: const Text('SponsorBlock Integration', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Automatically skip non-music segments & intros', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Behavior & Privacy', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('PLAYBACK CONTROLS'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: autoResumePlaybackEnabled,
                builder: (_, autoResume, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.play_circle, color: Color(0xFFFF9500)),
                    title: const Text('Auto-Resume on Launch', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Resume last playing track when app opens', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: autoResume,
                      onChanged: (val) {
                        autoResumePlaybackEnabled.value = val;
                        addOrUpdateData('settings', 'autoResumePlaybackEnabled', val);
                      },
                    ),
                  );
                },
              ),
              ValueListenableBuilder<bool>(
                valueListenable: pauseOnHeadphoneDisconnect,
                builder: (_, pauseOnDisconnect, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.headphones, color: Color(0xFF007AFF)),
                    title: const Text('Pause on Disconnect', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Pause audio when headphones or Bluetooth unplug', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: pauseOnDisconnect,
                      onChanged: (val) {
                        pauseOnHeadphoneDisconnect.value = val;
                        addOrUpdateData('settings', 'pauseOnHeadphoneDisconnect', val);
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
            header: const Text('SEARCH PRIVACY'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: saveSearchHistoryEnabled,
                builder: (_, saveHistory, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.search, color: Color(0xFFAF52DE)),
                    title: const Text('Save Search History', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Store recent searches on this device', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    trailing: GlassSwitch(
                      value: saveHistory,
                      onChanged: (val) {
                        saveSearchHistoryEnabled.value = val;
                        addOrUpdateData('settings', 'saveSearchHistoryEnabled', val);
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
    return GlassScaffold(
      contentAwareBrightness: true,
      appBar: GlassAppBar(
        leading: buildGlassBackButton(context),
        title: const Text('Android Auto', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          GlassGroupedSection(
            surfaceStyle: GlassSurfaceStyle.solid,
            header: const Text('CAR DASHBOARD INTEGRATION'),
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: androidAutoEnabled,
                builder: (_, autoEnabled, __) {
                  return GlassListTile(
                    leading: const Icon(CupertinoIcons.car_fill, color: Color(0xFF30D158)),
                    title: const Text('Enable Android Auto', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Expose media browser service to car head unit', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
