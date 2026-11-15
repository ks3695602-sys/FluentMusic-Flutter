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
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/glass/glass_control_panel.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
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

        return Stack(
          children: [
            Positioned.fill(
              child: _FullBleedArtworkBackground(artworkUrl: artworkUrl),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _lyricsController.isFlipped,
              builder: (context, isLyricsMode, _) {
                return GlassScaffold(
                  contentAwareBrightness: true,
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
                                  color: CupertinoColors.white.withValues(alpha: 0.35),
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
                  body: isLargeScreen
                      ? _DesktopLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                          lyricsController: _lyricsController,
                        )
                      : _MobileLayout(
                          metadata: metadata,
                          size: size,
                          adjustedIconSize: baseIconSize,
                          adjustedMiniIconSize: miniIconSize,
                          isLargeScreen: isLargeScreen,
                          lyricsController: _lyricsController,
                        ),
                );
              },
            ),
          ],
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
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;

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
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;

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

    return GlassPullDownButton(
      icon: const Icon(
        CupertinoIcons.ellipsis,
        color: CupertinoColors.white,
        size: 18,
      ),
      semanticLabel: 'More options',
      buttonWidth: 36,
      buttonHeight: 36,
      menuWidth: 248,
      items: [
        GlassMenuItem(
          title: 'Add to Playlist',
          subtitle: 'Choose or create a playlist',
          icon: const Icon(CupertinoIcons.plus_rectangle_on_rectangle),
          onTap: () => showAddToPlaylistDialog(
            context,
            songs: [mediaItemToMap(metadata)],
          ),
        ),
        GlassMenuItem(
          title: isOffline ? 'Remove Download' : 'Download for Offline',
          subtitle: isOffline
              ? 'Free up local storage'
              : 'Keep this song available offline',
          icon: Icon(
            isOffline
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.arrow_down_circle,
          ),
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
          title: 'Sleep Timer',
          subtitle: 'Stop playback after a delay',
          icon: const Icon(CupertinoIcons.timer),
          onTap: () => showSleepTimerDialog(context),
        ),
        GlassMenuItem(
          title: 'Lyrics Timing',
          subtitle: 'Shift synced lyrics earlier or later',
          icon: const Icon(CupertinoIcons.slider_horizontal_3),
          onTap: () => _showLyricsOffsetSheet(context),
        ),
        GlassMenuItem(
          title: 'Speed & Pitch',
          subtitle: 'Advanced playback controls',
          icon: const Icon(CupertinoIcons.speedometer),
          onTap: () => _showPlaybackSpeedSheet(context),
        ),
      ],
    );
  }

  void _showLyricsOffsetSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => ValueListenableBuilder<int>(
        valueListenable: lyricsOffsetMs,
        builder: (context, offset, _) {
          return CupertinoActionSheet(
            title: const Text('Lyrics Timing Sync Offset', style: TextStyle(fontWeight: FontWeight.bold)),
            message: Text(
              'Current Offset: ms\n(Tap ±250ms to nudge lyrics timing)',
            ),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  final newOffset = offset - 250;
                  lyricsOffsetMs.value = newOffset;
                  addOrUpdateData('settings', 'lyricsOffsetMs', newOffset);
                },
                child: const Text('◀ -250 ms (Lyrics Appear Earlier)'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  final newOffset = offset + 250;
                  lyricsOffsetMs.value = newOffset;
                  addOrUpdateData('settings', 'lyricsOffsetMs', newOffset);
                },
                child: const Text('▶ +250 ms (Lyrics Appear Later)'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  lyricsOffsetMs.value = 0;
                  addOrUpdateData('settings', 'lyricsOffsetMs', 0);
                },
                child: const Text('↺ Reset to Default (0 ms)'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          );
        },
      ),
    );
  }

  void _showPlaybackSpeedSheet(BuildContext context) {
    var speed = audioHandler.audioPlayer.speed.clamp(0.5, 2.0);
    var pitch = audioHandler.audioPlayer.pitch.clamp(0.5, 2.0);
    // 0 = Speed, 1 = Pitch, 2 = Both.
    var mode = 2;

    void apply(double nextSpeed, double nextPitch) {
      speed = nextSpeed.clamp(0.5, 2.0);
      pitch = nextPitch.clamp(0.5, 2.0);
      unawaited(audioHandler.setSpeed(speed));
      unawaited(audioHandler.setPitch(pitch));
    }

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          void applyFromSheet(double nextSpeed, double nextPitch) {
            setSheetState(() => apply(nextSpeed, nextPitch));
          }

          return GlassModalSheet(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
                      'Speed and pitch stay applied while the queue keeps '
                      'playing. Pitch is unaffected by speed unless you move '
                      'it yourself.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: CupertinoColors.white.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                  footer: Row(
                    children: [
                      Expanded(
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(14),
                          color: CupertinoColors.white.withValues(alpha: 0.12),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
