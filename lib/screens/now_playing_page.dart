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

import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/main.dart';
import 'package:flutter/services.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/player_style.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/glass/glass_control_panel.dart';
import 'package:musify/widgets/glass/glass_sheet_style.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/now_playing/player_style_sheet.dart';
import 'package:musify/widgets/now_playing/song_like_button.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:musify/widgets/queue_list_view.dart';
import 'package:musify/widgets/song_artwork.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        if (snapshot.data == null || !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final metadata = snapshot.data!;

        final artworkUrl = metadata.artUri?.toString();
        final pageGlassTheme =
            GlassTheme.maybeOf(context)?.data ?? GlassThemeData.fallback();

        return ValueListenableBuilder<PlayerStyle>(
          valueListenable: playerStyleSetting,
          builder: (context, playerStyle, _) {
            final body = isLargeScreen
                ? _DesktopLayout(
                    metadata: metadata,
                    size: size,
                    adjustedIconSize: baseIconSize,
                    adjustedMiniIconSize: miniIconSize,
                    lyricsController: _lyricsController,
                    playerStyle: playerStyle,
                  )
                : _MobileLayout(
                    metadata: metadata,
                    size: size,
                    adjustedIconSize: baseIconSize,
                    adjustedMiniIconSize: miniIconSize,
                    isLargeScreen: isLargeScreen,
                    lyricsController: _lyricsController,
                    playerStyle: playerStyle,
                  );

            return Stack(
              children: [
                Positioned.fill(
                  child: _PlayerBackdrop(
                    style: playerStyle,
                    artworkUrl: artworkUrl,
                  ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _lyricsController.isFlipped,
                  // The body handles the flip itself. Passing the same widget
                  // instance keeps the scaffold from rebuilding every control
                  // when the lyrics card turns over.
                  child: body,
                  builder: (context, isLyricsMode, child) {
                    // The player always sits on its own artwork under dark
                    // scrims. Pin the glass chrome dark locally so a light app
                    // theme never paints white-on-white header or menu glass
                    // over the art.
                    return GlassTheme(
                      data: pageGlassTheme.copyWith(brightness: Brightness.dark),
                      child: GlassScaffold(
                        // Brightness is pinned dark below, so sampling the
                        // backdrop every scroll frame would only burn frames.
                        contentAwareBrightness: false,
                        backgroundColor: Colors.transparent,
                        appBar: isLyricsMode
                            ? null
                            : GlassAppBar(
                                leading: GlassIconButton(
                                  icon: const Icon(CupertinoIcons.chevron_down),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                title: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 5,
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        borderRadius: BorderRadius.circular(2.5),
                                      ),
                                    ),
                                    Text(
                                      metadata.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        body: child!,
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
    required this.playerStyle,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;
  final PlayerStyle playerStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                      lyricsController: lyricsController,
                      playerStyle: playerStyle,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                _PlayFullSongButton(metadata: metadata),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: true,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
    required this.playerStyle,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;
  final PlayerStyle playerStyle;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return ValueListenableBuilder<bool>(
      valueListenable: lyricsController.isFlipped,
      builder: (context, isLyricsMode, _) {
        if (isLyricsMode && !isLive) {
          return SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // iOS Pull-Down Pill Grabber
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 5,
                        margin: const EdgeInsets.only(top: 6, bottom: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                  ),

                  // Image 3 Apple Karaoke Top Bar: Dismiss down + 44x44 thumbnail + title/artist + star + more
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        GlassIconButton(
                          icon: const Icon(CupertinoIcons.chevron_down, size: 20, color: CupertinoColors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: lyricsController.flipcard,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: SongArtworkWidget(
                                metadata: metadata,
                                size: 44,
                                borderRadius: 10,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: lyricsController.flipcard,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                metadata.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                metadata.artist ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: CupertinoColors.white.withValues(alpha: 0.65),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildFavoriteStar(metadata),
                      const SizedBox(width: 6),
                      _buildMoreButton(context, metadata),
                    ],
                  ),
                ),

                // Center: Expansive Word-by-Word Apple Karaoke Lyrics (Image 3)
                Expanded(
                  child: LyricsViewWidget(metadata: metadata),
                ),

                // Bottom: Position slider + compact playback controls + 3-item trio
                const PositionSlider(),
                _buildCompactControls(context),
                _PlayFullSongButton(metadata: metadata),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          );
        }

        // Standard Apple Music Player Screen (Image 2 & Image 4)
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(
                flex: 5,
                child: Center(
                  child: NowPlayingArtwork(
                    size: size,
                    metadata: metadata,
                    lyricsController: lyricsController,
                    playerStyle: playerStyle,
                  ),
                ),
              ),
              if (!isLive)
                Expanded(
                  flex: 4,
                  child: NowPlayingControls(
                    size: size,
                    audioId: metadata.extras?['ytid'],
                    adjustedIconSize: adjustedIconSize,
                    adjustedMiniIconSize: adjustedMiniIconSize,
                    metadata: metadata,
                  ),
                ),
              _PlayFullSongButton(metadata: metadata),
              BottomActionsRow(
                metadata: metadata,
                iconSize: adjustedMiniIconSize,
                isLargeScreen: isLargeScreen,
                lyricsController: lyricsController,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFavoriteStar(MediaItem metadata) {
    final audioId = metadata.extras?['ytid']?.toString();
    final isRadioStation = metadata.extras?['isLive'] == true;

    if (!isRadioStation) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: SongLikeButton(
          songId: audioId,
          songData: mediaItemToMap(metadata),
          iconSize: 18,
          minSize: 36,
        ),
      );
    }

    return ValueListenableBuilder<List>(
      valueListenable: userLikedRadioStations,
      builder: (context, _, __) {
        final isLiked = isRadioStationLiked(audioId ?? '');
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            if (audioId == null) return;
            HapticFeedback.lightImpact();
            if (isLiked) {
              await removeRadioStationFromLiked(audioId);
            } else {
              await addRadioStationToLiked(audioId);
            }
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: CupertinoColors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
              size: 18,
              color: isLiked ? const Color(0xFFFF2D55) : CupertinoColors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreButton(BuildContext context, MediaItem metadata) {
    final audioId = metadata.extras?['ytid']?.toString();
    final isOffline = isSongAlreadyOffline(audioId);

    return DarkGlassMenuTheme(
      child: GlassPullDownButton(
      icon: const Icon(
        CupertinoIcons.ellipsis,
        color: CupertinoColors.white,
        size: 18,
      ),
      semanticLabel: 'More options',
      buttonWidth: 36,
      buttonHeight: 36,
      menuWidth: 300,
      maxStackHeight: MediaQuery.sizeOf(context).height * 0.62,
      settings: glassSheetSettings(context, brightness: Brightness.dark),
      items: [
        const GlassMenuLabel(title: 'Now playing'),
        GlassMenuItem(
          title: 'Player Style',
          subtitle: playerStyleSetting.value.label,
          icon: const Icon(CupertinoIcons.paintbrush),
          onTap: () => showPlayerStyleSheet(context),
        ),
        GlassMenuItem(
          title: 'Add to Playlist',
          icon: const Icon(CupertinoIcons.plus_rectangle_on_rectangle),
          onTap: () => showAddToPlaylistDialog(
            context,
            songs: [mediaItemToMap(metadata)],
          ),
        ),
        GlassMenuItem(
          title: isOffline ? 'Downloaded' : 'Save Offline',
          subtitle: isOffline
              ? 'On this device'
              : 'Available without data',
          icon: Icon(
            isOffline
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.arrow_down_circle,
          ),
          isSelected: isOffline,
          semanticsSelected: isOffline,
          isDestructive: isOffline,
          onTap: () async {
            if (audioId == null) return;
            if (isSongAlreadyOffline(audioId)) {
              await OfflinePlaylistService().removeSongFromOfflineAndResync(
                audioId,
              );
              if (context.mounted) {
                showToast(context, 'Removed from offline storage');
              }
            } else {
              final success = await makeSongOffline(mediaItemToMap(metadata));
              if (context.mounted && success) {
                showToast(context, 'Downloaded for offline playback');
              }
            }
          },
        ),
        const GlassMenuDivider(),
        GlassMenuItem(
          title: 'Playback',
          subtitle: 'Timer, lyrics & speed',
          icon: const Icon(CupertinoIcons.slider_horizontal_3),
          onTap: () {},
          submenu: [
            GlassMenuItem(
              title: 'Sleep Timer',
              icon: const Icon(CupertinoIcons.timer),
              onTap: () => showSleepTimerDialog(context),
            ),
            GlassMenuItem(
              title: 'Lyrics Timing',
              subtitle: 'Offset lines by ±250 ms',
              icon: const Icon(CupertinoIcons.music_note_list),
              onTap: () => _showLyricsOffsetSheet(context),
            ),
            GlassMenuItem(
              title: 'Speed & Pitch',
              subtitle: 'Change speed and pitch',
              icon: const Icon(CupertinoIcons.speedometer),
              onTap: () => _showPlaybackSpeedSheet(context),
            ),
          ],
        ),
      ],
      ),
    );
  }

  Future<void> _showLyricsOffsetSheet(BuildContext context) {
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

        Widget offsetRow({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
        }) {
          return CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: onTap,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: rowColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: rowColor,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 20, color: labelColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Lyrics Timing',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 4),
                ValueListenableBuilder<int>(
                  valueListenable: lyricsOffsetMs,
                  builder: (context, offset, _) {
                    final sign = offset > 0 ? '+' : '';
                    return Text(
                      offset == 0
                          ? 'Perfectly in sync at 0 ms.'
                          : 'Currently nudged by $sign${offset}ms.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: subtitleColor,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
                offsetRow(
                  icon: CupertinoIcons.gobackward_10,
                  title: 'Earlier by 250 ms',
                  subtitle: 'Lyrics show up before the singer inhales',
                  onTap: () {
                    final newOffset = lyricsOffsetMs.value - 250;
                    lyricsOffsetMs.value = newOffset;
                    addOrUpdateData('settings', 'lyricsOffsetMs', newOffset);
                  },
                ),
                offsetRow(
                  icon: CupertinoIcons.goforward_10,
                  title: 'Later by 250 ms',
                  subtitle: 'For when the lyrics spoil the drop',
                  onTap: () {
                    final newOffset = lyricsOffsetMs.value + 250;
                    lyricsOffsetMs.value = newOffset;
                    addOrUpdateData('settings', 'lyricsOffsetMs', newOffset);
                  },
                ),
                offsetRow(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  title: 'Reset to 0 ms',
                  subtitle: 'Back to factory sync, no questions asked',
                  onTap: () {
                    lyricsOffsetMs.value = 0;
                    addOrUpdateData('settings', 'lyricsOffsetMs', 0);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPlaybackSpeedSheet(BuildContext context) {
    var speed = audioHandler.audioPlayer.speed.clamp(0.5, 2.0);
    var pitch = audioHandler.audioPlayer.pitch.clamp(0.5, 2.0);
    // 0 = Speed, 1 = Pitch, 2 = Both.
    var mode = 2;
    final brightness = GlassTheme.brightnessOf(context);

    void apply(double nextSpeed, double nextPitch) {
      speed = nextSpeed.clamp(0.5, 2.0);
      pitch = nextPitch.clamp(0.5, 2.0);
      unawaited(audioHandler.setSpeed(speed));
      unawaited(audioHandler.setPitch(pitch));
    }

    return GlassModalSheet.show<void>(
      context: context,
      // This panel includes two sliders, presets and a footer. Start expanded
      // so Done is immediately visible instead of below the medium detent.
      initialState: GlassSheetState.full,
      detents: const {GlassSheetDetent.medium, GlassSheetDetent.large},
      halfSize: 0.68,
      settings: glassSheetSettings(context, brightness: brightness),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void applyFromSheet(double nextSpeed, double nextPitch) {
            setSheetState(() => apply(nextSpeed, nextPitch));
          }

          // Pin the sheet's internal widgets (segmented control, sliders,
          // badges) to the same variant the sheet itself paints, so text and
          // glass can never disagree.
          final parentTheme =
              GlassTheme.maybeOf(sheetContext)?.data ??
              GlassThemeData.fallback();
          final controlColors = glassControlColors(
            context,
            brightness: brightness,
          );

          return GlassTheme(
            data: parentTheme.copyWith(brightness: brightness),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: GlassControlPanel(
                        title: 'Speed & Pitch',
                        subtitle:
                            'Applied live. Tap a value badge to reset that control.',
                        children: [
                          GlassSegmentedControl(
                            segments: const [
                              GlassSegment(label: 'Speed'),
                              GlassSegment(label: 'Pitch'),
                              GlassSegment(label: 'Both'),
                            ],
                            selectedIndex: mode,
                            indicatorColor: brightness == Brightness.dark
                                ? const Color(0xFF3A3A3C)
                                : const Color(0xFFE5E5EA),
                            backgroundColor: brightness == Brightness.dark
                                ? const Color(0xFF1C1C1E)
                                : const Color(0xFFF2F2F7),
                            selectedTextStyle: TextStyle(
                              color: brightness == Brightness.dark
                                  ? CupertinoColors.white
                                  : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w600,
                            ),
                            unselectedTextStyle: TextStyle(
                              color: controlColors.subtitle,
                              fontWeight: FontWeight.w500,
                            ),
                            onSegmentSelected: (index) {
                              setSheetState(() => mode = index);
                            },
                          ),
                          const SizedBox(height: 18),
                          if (mode != 1)
                            GlassControlSlider(
                              label: 'Speed',
                              valueLabel: '${speed.toStringAsFixed(2)}x',
                              value: speed,
                              min: 0.5,
                              max: 2.0,
                              divisions: 30,
                              accent: const Color(0xFF0A84FF),
                              onChanged: (value) {
                                setSheetState(() => speed = value);
                                unawaited(audioHandler.setSpeed(value));
                              },
                              onReset: () => applyFromSheet(1.0, pitch),
                            ),
                          if (mode != 0)
                            GlassControlSlider(
                              label: 'Pitch',
                              valueLabel: pitch.toStringAsFixed(2),
                              value: pitch,
                              min: 0.5,
                              max: 2.0,
                              divisions: 150,
                              accent: const Color(0xFFFF9500),
                              onChanged: (value) {
                                setSheetState(() => pitch = value);
                                unawaited(audioHandler.setPitch(value));
                              },
                              onReset: () => applyFromSheet(speed, 1.0),
                            ),
                          const SizedBox(height: 4),
                          GlassControlPresets(
                            presets: const [
                              'Normal',
                              '1.25x',
                              '1.50x',
                              '0.85x',
                              'Nightcore',
                              'Reset all',
                            ],
                            onSelected: (label) {
                              if (label == '1.25x') {
                                applyFromSheet(1.25, 1.0);
                              } else if (label == '1.50x') {
                                applyFromSheet(1.5, 1.0);
                              } else if (label == '0.85x') {
                                applyFromSheet(0.85, 0.85);
                              } else if (label == 'Nightcore') {
                                applyFromSheet(1.3, 1.3);
                              } else {
                                applyFromSheet(1.0, 1.0);
                              }
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Speed and pitch stay applied while the queue '
                            'keeps playing. Pitch is unaffected by speed '
                            'unless you move it yourself.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: controlColors.subtitle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        borderRadius: BorderRadius.circular(14),
                        color: controlColors.badge,
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: controlColors.title,
                          ),
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
    );
  }

  Widget _buildCompactControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.backward_fill),
            iconSize: 28,
            color: CupertinoColors.white,
            onPressed: audioHandler.skipToPrevious,
          ),
          const SizedBox(width: 24),
          const PlaybackIconButton(
            iconSize: 54,
            iconColor: CupertinoColors.white,
            backgroundColor: Colors.transparent,
          ),
          const SizedBox(width: 24),
          IconButton(
            icon: const Icon(CupertinoIcons.forward_fill),
            iconSize: 28,
            color: CupertinoColors.white,
            onPressed: audioHandler.skipToNext,
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    final isLive = metadata.extras?['isLive'] ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
                playerStyle: playerStyle,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isLive)
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                _PlayFullSongButton(metadata: metadata),
                BottomActionsRow(
                  metadata: metadata,
                  iconSize: adjustedMiniIconSize,
                  isLargeScreen: isLargeScreen,
                  lyricsController: lyricsController,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-bleed, edge-to-edge player backdrop.
///
/// The artwork is drawn behind the status bar and the gesture handle, with no
/// hard edges anywhere:
///   * a heavily blurred copy fills the whole viewport
///   * a sharper copy is revealed through a vertical mask, so the centre reads
///     as real artwork while the top and bottom melt back into the blur
///   * two gradient scrims keep the header and controls legible
///
/// Everything sits inside a [RepaintBoundary] so playback ticks never
/// re-rasterise the blurred image.
class _FullBleedArtworkBackground extends StatelessWidget {
  const _FullBleedArtworkBackground({required this.artworkUrl});

  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    final url = artworkUrl?.trim();

    if (url == null || url.isEmpty) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A1435),
              Color(0xFF140B1D),
              Color(0xFF000000),
            ],
          ),
        ),
      );
    }

    final provider = ArtworkProvider.get(url);

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF050409)),

          // Blurred bed: over-scaled so blur never samples transparent edges.
          Transform.scale(
            scale: 1.25,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: 70,
                sigmaY: 70,
                tileMode: TileMode.clamp,
              ),
              child: Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

          // Sharper artwork, faded in from the blur at both ends.
          ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x00000000),
                Color(0xB3000000),
                Color(0xB3000000),
                Color(0x00000000),
              ],
              stops: [0.0, 0.2, 0.62, 0.95],
            ).createShader(bounds),
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

          // Top scrim: status bar and page header.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xCC000000),
                  Color(0x66000000),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.18, 0.42],
              ),
            ),
          ),

          // Bottom scrim: controls and gesture handle.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF2000000),
                  Color(0xB3000000),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.28, 0.62],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The full-bleed backdrop for the active [PlayerStyle].
///
/// Immersive keeps the original blurred artwork bed. Midnight and Vinyl paint
/// a static stage instead, which removes the huge artwork blur from the frame
/// budget while keeping the glass controls readable.
class _PlayerBackdrop extends StatelessWidget {
  const _PlayerBackdrop({required this.style, required this.artworkUrl});

  final PlayerStyle style;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (style == PlayerStyle.immersive)
          _FullBleedArtworkBackground(artworkUrl: artworkUrl)
        else
          _PlayerStageBackground(style: style),

        // Graduated frost under the transport controls. The artwork bed is
        // already blurred once at sigma 70, so a live `ProgressiveBlur` (two
        // more shader BackdropFilter passes over the whole lower third) only
        // bought a per-frame GPU bill on device. A static gradient gives the
        // same soft landing for free.
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: SizedBox(
              height: 260,
              width: double.infinity,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0x40000000),
                      Color(0x1F000000),
                      Color(0x00000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Static stage used by [PlayerStyle.midnight] and [PlayerStyle.vinyl].
///
/// No images, no live blur: a deep vertical gradient plus one accent glow.
class _PlayerStageBackground extends StatelessWidget {
  const _PlayerStageBackground({required this.style});

  final PlayerStyle style;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isVinyl = style == PlayerStyle.vinyl;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isVinyl
                ? const [
                    Color(0xFF241A12),
                    Color(0xFF0C0805),
                    Color(0xFF000000),
                  ]
                : const [
                    Color(0xFF13131B),
                    Color(0xFF08080C),
                    Color(0xFF000000),
                  ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -140,
              left: -100,
              right: -100,
              height: 560,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: isVinyl ? 0.30 : 0.22),
                      accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Top scrim keeps the status bar and header legible.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                  stops: [0.0, 0.42],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown while a Shorts/Explore preview is playing in the normal player.
///
/// The preview is already the full stream, so upgrading does not reload the
/// track: it clears the preview flag, rewinds when the clip had stopped at its
/// limit, and resumes.
class _PlayFullSongButton extends StatelessWidget {
  const _PlayFullSongButton({required this.metadata});

  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    if (metadata.extras?['isPreview'] != true) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassButton.custom(
        onTap: () {
          HapticFeedback.lightImpact();
          unawaited(audioHandler.playFullSong());
        },
        height: 38,
        width: 188,
        shape: const LiquidRoundedRectangle(borderRadius: 19),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              CupertinoIcons.play_fill,
              size: 13,
              color: CupertinoColors.white,
            ),
            SizedBox(width: 6),
            Text(
              'Play Full Song',
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
