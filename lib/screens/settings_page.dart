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
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/update_manager.dart';
import 'package:musify/theme/app_colors.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/language_utils.dart';
import 'package:musify/utilities/platform_utils.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      contentAwareBrightness: true,
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0C0910),
              Color(0xFF1A0B1C),
              Color(0xFF100B18),
            ],
          ),
        ),
      ),
      appBar: GlassAppBar(
        title: Text(
          context.l10n?.settings ?? 'Settings',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // 1. LIQUID GLASS & GRAPHICS PIPELINE
          _buildSectionHeader('LIQUID GLASS & GRAPHICS PIPELINE'),
          _buildLiquidGlassSection(context),

          const SizedBox(height: 20),

          // 2. PREFERENCES & APPEARANCE
          _buildSectionHeader(context.l10n?.preferences?.toUpperCase() ?? 'PREFERENCES'),
          _buildPreferencesSection(context),

          const SizedBox(height: 20),

          // 3. PLAYBACK & ONLINE FEATURES
          if (!offlineMode.value) ...[
            _buildSectionHeader('PLAYBACK & ONLINE FEATURES'),
            _buildOnlineFeaturesSection(context),
            const SizedBox(height: 20),
          ],

          // 4. TOOLS & DATA MANAGEMENT
          _buildSectionHeader(context.l10n?.tools?.toUpperCase() ?? 'TOOLS & STORAGE'),
          _buildToolsSection(context),

          const SizedBox(height: 20),

          // 5. ABOUT FLUENTMUSIC
          _buildSectionHeader('ABOUT FLUENTMUSIC'),
          _buildAboutSection(context),

          const SizedBox(height: 24),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white54,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildLiquidGlassSection(BuildContext context) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: appleMusicLyricsEnabled,
          builder: (_, value, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.music_mic, color: Color(0xFFFA2D48)),
              title: const Text('Apple Music Synced Lyrics', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Dynamic glowing lyrics with real-time word tracking',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: value,
                onChanged: (val) {
                  addOrUpdateData<bool>('settings', 'appleMusicLyricsEnabled', val);
                  appleMusicLyricsEnabled.value = val;
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<String>(
          valueListenable: liquidGlassQualitySetting,
          builder: (_, quality, __) {
            final selectedIndex = quality == 'premium' ? 0 : (quality == 'standard' ? 1 : 2);
            return GlassListTile(
              leading: const Icon(CupertinoIcons.sparkles, color: Color(0xFFAF52DE)),
              title: const Text('Impeller Shader Tier', style: TextStyle(color: Colors.white)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: GlassSegmentedControl(
                  segments: const [
                    GlassSegment(label: 'Premium'),
                    GlassSegment(label: 'Standard'),
                    GlassSegment(label: 'Minimal'),
                  ],
                  selectedIndex: selectedIndex,
                  onSegmentSelected: (index) {
                    final newTier = index == 0 ? 'premium' : (index == 1 ? 'standard' : 'minimal');
                    addOrUpdateData<String>('settings', 'liquidGlassQuality', newTier);
                    liquidGlassQualitySetting.value = newTier;
                    showToast(context, 'Shader tier set to ${newTier.toUpperCase()}');
                  },
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<double>(
          valueListenable: liquidGlassBlurSetting,
          builder: (_, blurValue, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.slider_horizontal_3, color: Color(0xFF32ADE6)),
              title: const Text('Refraction & Blur Intensity', style: TextStyle(color: Colors.white)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoSlider(
                        value: blurValue,
                        min: 6,
                        max: 32,
                        divisions: 13,
                        activeColor: const Color(0xFFFA2D48),
                        onChanged: (val) {
                          addOrUpdateData<double>('settings', 'liquidGlassBlur', val);
                          liquidGlassBlurSetting.value = val;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${blurValue.toInt()}px',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const GlassListTile(
          leading: Icon(CupertinoIcons.cpu, color: Color(0xFF34C759)),
          title: Text('Impeller Optics Engine', style: TextStyle(color: Colors.white)),
          subtitle: Text(
            'Multi-pass blur, chromatic aberration & specular highlights',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Icon(CupertinoIcons.checkmark_seal_fill, color: Color(0xFF34C759), size: 20),
        ),
      ],
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        GlassListTile(
          leading: const Icon(CupertinoIcons.paintbrush_fill, color: Color(0xFFFF9500)),
          title: Text(context.l10n?.accentColor ?? 'Accent Color', style: const TextStyle(color: Colors.white)),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: primaryColorSetting,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 2),
            ),
          ),
          onTap: () => _showAccentColorPicker(context),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.sun_max_fill, color: Color(0xFFFFCC00)),
          title: Text(context.l10n?.themeMode ?? 'Theme Mode', style: const TextStyle(color: Colors.white)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: GlassSegmentedControl(
              segments: const [
                GlassSegment(label: 'System'),
                GlassSegment(label: 'Light'),
                GlassSegment(label: 'Dark'),
              ],
              selectedIndex: themeMode == ThemeMode.system ? 0 : (themeMode == ThemeMode.light ? 1 : 2),
              onSegmentSelected: (index) {
                final mode = index == 0 ? ThemeMode.system : (index == 1 ? ThemeMode.light : ThemeMode.dark);
                addOrUpdateData<int>('settings', 'themeIndex', mode.index);
                Musify.updateAppState(context, newThemeMode: mode);
              },
            ),
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.globe, color: Color(0xFF007AFF)),
          title: Text(context.l10n?.language ?? 'Language', style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            getLanguageDisplayName(context, languageSetting.languageCode),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: GlassListTile.chevron,
          onTap: () => _showLanguagePicker(context),
        ),
        ValueListenableBuilder<String>(
          valueListenable: audioQualitySetting,
          builder: (_, quality, __) {
            final selectedIndex = quality == 'low' ? 0 : (quality == 'medium' ? 1 : 2);
            return GlassListTile(
              leading: const Icon(CupertinoIcons.waveform, color: Color(0xFF5856D6)),
              title: Text(context.l10n?.audioQuality ?? 'Audio Quality', style: const TextStyle(color: Colors.white)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: GlassSegmentedControl(
                  segments: const [
                    GlassSegment(label: 'Low'),
                    GlassSegment(label: 'Medium'),
                    GlassSegment(label: 'High'),
                  ],
                  selectedIndex: selectedIndex,
                  onSegmentSelected: (index) {
                    final val = index == 0 ? 'low' : (index == 1 ? 'medium' : 'high');
                    addOrUpdateData<String>('settings', 'audioQuality', val);
                    audioQualitySetting.value = val;
                    showToast(context, context.l10n!.audioQualityMsg);
                  },
                ),
              ),
            );
          },
        ),
        if (isAndroidPlatform)
          GlassListTile(
            leading: const Icon(CupertinoIcons.slider_horizontal_below_rectangle, color: Color(0xFF30D158)),
            title: Text(context.l10n?.equalizer ?? 'Equalizer', style: const TextStyle(color: Colors.white)),
            trailing: GlassListTile.chevron,
            onTap: () => context.push('/settings/equalizer'),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: usePureBlackColor,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.moon_fill, color: Color(0xFF8E8E93)),
              title: Text(context.l10n?.pureBlackTheme ?? 'Pure Black (OLED)', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.pureBlackThemeDescription ?? 'Deep OLED pitch black in dark mode',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _togglePureBlack(context, v),
              ),
            );
          },
        ),
        if (isAndroidPlatform)
          ValueListenableBuilder<bool>(
            valueListenable: useSystemColor,
            builder: (_, val, __) {
              return GlassListTile(
                leading: const Icon(CupertinoIcons.wand_stars, color: Color(0xFFFF2D55)),
                title: Text(context.l10n?.dynamicColor ?? 'Dynamic Colors', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  context.l10n?.dynamicColorDescription ?? 'Derive palette from system wallpaper',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: GlassSwitch(
                  value: val,
                  onChanged: (v) => _toggleSystemColor(context, v),
                ),
              );
            },
          ),
        ValueListenableBuilder<bool>(
          valueListenable: showAudioQualityBadge,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.app_badge, color: Color(0xFF64D2FF)),
              title: Text(context.l10n?.audioQualityBadge ?? 'Audio Quality Badge', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.audioQualityBadgeDescription ?? 'Display Lossless / HQ tag on tracks',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleAudioQualityBadge(context, v),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: offlineMode,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.cloud_slash, color: Color(0xFFFF453A)),
              title: Text(context.l10n?.offlineMode ?? 'Offline Mode', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.offlineModeDescription ?? 'Browse downloaded tracks only',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleOfflineMode(context, v),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: wrappedEnabled,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.chart_bar_square, color: Color(0xFFBF5AF2)),
              title: Text(context.l10n?.listeningStats ?? 'Listening Stats', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.listeningStatsDescription ?? 'Track your listening recap over time',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleWrapped(context, v),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: syncedLyricsEnabled,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.quote_bubble, color: Color(0xFF007AFF)),
              title: Text(context.l10n?.syncedLyrics ?? 'Synced Lyrics', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.syncedLyricsDescription ?? 'Fetch and display synchronized lyrics',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleSyncedLyrics(context, v),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.forward_end, color: Color(0xFF34C759)),
              title: Text(context.l10n?.automaticSongPicker ?? 'Auto Song Picker', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.automaticSongPickerDescription ?? 'Automatically enqueue related music',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) {
                  _toggleAutoPlayNext(context, v);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: sponsorBlockSupport,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.scissors, color: Color(0xFFFF9500)),
              title: const Text('SponsorBlock', style: TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.sponsorBlockDescription ?? 'Skip sponsored video segments automatically',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleSponsorBlock(context, v),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.radiowaves_right, color: Color(0xFFAF52DE)),
              title: Text(context.l10n?.externalRecommendations ?? 'External Recommendations', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.externalRecommendationsDescription ?? 'Discover trending songs across external APIs',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) => _toggleExternalRecommendations(context, v),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: useProxy,
          builder: (_, val, __) {
            return GlassListTile(
              leading: const Icon(CupertinoIcons.shield, color: Color(0xFF5AC8FA)),
              title: Text(context.l10n?.useProxy ?? 'Proxy Support', style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                context.l10n?.useProxyDescription ?? 'Route streaming requests via proxy server',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: GlassSwitch(
                value: val,
                onChanged: (v) {
                  useProxy.value = v;
                  addOrUpdateData<bool>('settings', 'useProxy', v);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        if (!isFdroidBuild && isMobilePlatform)
          ValueListenableBuilder<bool?>(
            valueListenable: shouldWeCheckUpdates,
            builder: (_, val, __) {
              return GlassListTile(
                leading: const Icon(CupertinoIcons.arrow_2_circlepath, color: Color(0xFF30D158)),
                title: Text(context.l10n?.automaticUpdateChecks ?? 'Auto Updates', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  context.l10n?.automaticUpdateChecksDescription ?? 'Notify when a new version is released',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: GlassSwitch(
                  value: val ?? false,
                  onChanged: (v) => _toggleAutomaticUpdateChecks(context, v),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        GlassListTile(
          leading: const Icon(CupertinoIcons.trash, color: Color(0xFFFF9500)),
          title: Text(context.l10n?.clearCache ?? 'Clear Cache', style: const TextStyle(color: Colors.white)),
          subtitle: const Text('Free up temporary image and audio buffers', style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: GlassListTile.chevron,
          onTap: () async {
            final cleared = await clearCache();
            showToast(context, cleared ? '${context.l10n!.cacheMsg}!' : context.l10n!.error);
          },
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.clock, color: Color(0xFF5AC8FA)),
          title: Text(context.l10n?.clearSearchHistory ?? 'Clear Search History', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n?.clearSearchHistoryQuestion ?? 'Clear all search queries?',
            onSubmit: () {
              searchHistoryNotifier.value = [];
              deleteData('user', 'searchHistory');
              showToast(context, '${context.l10n!.searchHistoryMsg}!');
            },
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.play_circle, color: Color(0xFF34C759)),
          title: Text(context.l10n?.clearRecentlyPlayed ?? 'Clear Recently Played', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n?.clearRecentlyPlayedQuestion ?? 'Clear history of played tracks?',
            onSubmit: () {
              userRecentlyPlayed.value = [];
              deleteData('user', 'recentlyPlayedSongs');
              showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
            },
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.chart_pie, color: Color(0xFFAF52DE)),
          title: Text(context.l10n?.clearListeningStats ?? 'Clear Listening Stats', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n?.clearListeningStatsQuestion ?? 'Reset all accumulated listening statistics?',
            submitMessage: context.l10n?.delete ?? 'Delete',
            isDangerous: true,
            onSubmit: () async {
              audioHandler.resetListeningStatsSession(flushStats: false);
              await listeningStatsService.clearStats();
              audioHandler.startListeningStatsSessionIfNeeded();
              if (context.mounted) {
                showToast(context, '${context.l10n!.listeningStatsCleared}!');
              }
            },
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.delete_solid, color: Color(0xFFFF3B30)),
          title: Text(context.l10n?.deleteDownloads ?? 'Delete All Downloads', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n?.deleteDownloadsQuestion ?? 'Delete all locally downloaded tracks and playlists?',
            submitMessage: context.l10n?.delete ?? 'Delete',
            isDangerous: true,
            onSubmit: () async {
              try {
                await offlinePlaylistService.deleteAllDownloads();
                if (context.mounted) {
                  showToast(context, context.l10n!.downloadsDeleted);
                }
              } catch (_) {
                if (context.mounted) {
                  showToast(context, context.l10n!.error);
                }
              }
            },
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.square_arrow_down, color: Color(0xFF30D158)),
          title: Text(context.l10n?.importSpotifyPlaylist ?? 'Import Spotify Playlist', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => context.push('/settings/import-spotify-playlist'),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.arrow_up_doc, color: Color(0xFF007AFF)),
          title: Text(context.l10n?.backupUserData ?? 'Backup User Data', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _backupUserData(context),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.arrow_down_doc, color: Color(0xFF5856D6)),
          title: Text(context.l10n?.restoreUserData ?? 'Restore User Data', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => _restoreUserData(context),
        ),
        if (!isFdroidBuild && isMobilePlatform)
          GlassListTile(
            leading: const Icon(CupertinoIcons.arrow_down_circle_fill, color: Color(0xFF34C759)),
            title: Text(context.l10n?.downloadAppUpdate ?? 'Check for Updates', style: const TextStyle(color: Colors.white)),
            trailing: GlassListTile.chevron,
            onTap: checkAppUpdates,
          ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return GlassGroupedSection(
      surfaceStyle: GlassSurfaceStyle.solid,
      children: [
        GlassListTile(
          leading: const Icon(CupertinoIcons.music_note_list, color: Color(0xFFFA2D48)),
          title: const Text('FluentMusic', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: const Text('v1.2.0 • Liquid Glass Edition', style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: const Text('Open Source', style: TextStyle(color: Colors.white38, fontSize: 12)),
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.person_crop_circle_fill, color: Color(0xFF007AFF)),
          title: const Text('Lead Developer', style: TextStyle(color: Colors.white)),
          subtitle: const Text('jaypakash sahu', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: GlassListTile.chevron,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.doc_plaintext, color: Color(0xFFFF9500)),
          title: Text(context.l10n?.licenses ?? 'Open Source Licenses', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => NavigationManager.router.go('/settings/license'),
        ),
        ValueListenableBuilder<int>(
          valueListenable: logger.logCount,
          builder: (ctx, logCount, _) => GlassListTile(
            leading: const Icon(CupertinoIcons.square_list, color: Color(0xFF64D2FF)),
            title: Text('${context.l10n?.copyLogs ?? "Export Diagnostics"} ($logCount)', style: const TextStyle(color: Colors.white)),
            trailing: GlassListTile.chevron,
            onTap: () async => showToast(context, await logger.copyLogs(context)),
          ),
        ),
        GlassListTile(
          leading: const Icon(CupertinoIcons.info_circle, color: Color(0xFF34C759)),
          title: Text(context.l10n?.about ?? 'About FluentMusic', style: const TextStyle(color: Colors.white)),
          trailing: GlassListTile.chevron,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
      ],
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
          ),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: availableColors.length,
          itemBuilder: (context, index) {
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return GestureDetector(
              onTap: () => _selectAccentColor(context, color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.white, width: 3.5)
                      : Border.all(color: Colors.white24, width: 1.5),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        CupertinoIcons.checkmark,
                        color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  void _selectAccentColor(BuildContext context, Color color) {
    addOrUpdateData<int>('settings', 'accentColor', color.toARGB32());
    Musify.updateAppState(
      context,
      newAccentColor: color,
      useSystemColor: false,
    );
    showToast(context, context.l10n?.accentChangeMsg ?? 'Accent color updated');
    Navigator.of(context).pop();
  }

  void _showLanguagePicker(BuildContext context) {
    final availableLanguages = appLanguages.toList();
    final activeLanguageCode = Localizations.localeOf(context).languageCode;
    final activeScriptCode = Localizations.localeOf(context).scriptCode;
    final activeLanguageFullCode = activeScriptCode != null
        ? '$activeLanguageCode-$activeScriptCode'
        : activeLanguageCode;

    Widget buildLanguageBar(int index) {
      final language = availableLanguages[index];
      final newLocale = getLocaleFromLanguageCode(language);
      final newLocaleFullCode = newLocale.scriptCode != null
          ? '${newLocale.languageCode}-${newLocale.scriptCode}'
          : newLocale.languageCode;

      return BottomSheetBar(
        getLanguageDisplayName(context, language),
        () {
          addOrUpdateData<String>('settings', 'languageCode', newLocaleFullCode);
          Musify.updateAppState(context, newLocale: newLocale);
          showToast(context, context.l10n?.languageMsg ?? 'Language changed');
          Navigator.of(context).pop();
        },
        activeLanguageFullCode == newLocaleFullCode,
      );
    }

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableLanguages.length,
        itemBuilder: (context, index) => buildLanguageBar(index),
      ),
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Musify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAudioQualityBadge(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'showAudioQualityBadge', value);
    showAudioQualityBadge.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSyncedLyrics(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'syncedLyricsEnabled', value);
    syncedLyricsEnabled.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;
    NavigationManager.refreshRouter();
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleSponsorBlock(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'sponsorBlockSupport', value);
    sponsorBlockSupport.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutomaticUpdateChecks(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', value);
    shouldWeCheckUpdates.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n?.clear ?? 'Clear',
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(ctx).pop(),
          onSubmit: () {
            Navigator.of(ctx).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    try {
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : CupertinoIcons.exclamationmark_circle,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n?.error ?? 'Error',
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
  }

  Future<void> _restoreUserData(BuildContext context) async {
    try {
      final result = await restoreData(context);
      if (result.success) {
        reloadSettingsFromStorage();
        reloadSongLibraryStateFromStorage();
        reloadPlaylistLibraryStateFromStorage();
        reloadSearchHistoryFromStorage();
        listeningStatsService.reload();
        await audioHandler.setShuffleMode(
          shuffleNotifier.value
              ? AudioServiceShuffleMode.all
              : AudioServiceShuffleMode.none,
        );
        await audioHandler.setRepeatMode(repeatNotifier.value);
        themeMode = getThemeMode(themeModeSetting);
        brightness = getBrightnessFromThemeMode(themeMode);
        if (context.mounted) {
          await Musify.updateAppState(
            context,
            newThemeMode: themeMode,
            newLocale: languageSetting,
            newAccentColor: primaryColorSetting,
            useSystemColor: useSystemColor.value,
          );
          NavigationManager.refreshRouter();
        }
      }
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : CupertinoIcons.exclamationmark_circle,
        );
      }
    } catch (e, str) {
      logger.log('Error restoring data', error: e, stackTrace: str);
      if (context.mounted) {
        showToast(
          context,
          context.l10n?.error ?? 'Error',
          icon: CupertinoIcons.exclamationmark_circle,
        );
      }
    }
  }
}
