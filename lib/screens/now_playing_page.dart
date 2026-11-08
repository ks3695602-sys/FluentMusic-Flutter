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

import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:musify/utilities/artwork_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' hide ColorScheme;
import 'package:musify/main.dart';
import 'package:flutter/services.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/widgets/flip_card.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
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
              child: Container(
                color: CupertinoColors.black,
                child: artworkUrl != null && artworkUrl.isNotEmpty
                    ? ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                        child: Transform.scale(
                          scale: 1.4,
                          child: Opacity(
                            opacity: 0.50,
                            child: Image(
                              image: ArtworkProvider.get(artworkUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      CupertinoColors.black.withValues(alpha: 0.35),
                      CupertinoColors.black.withValues(alpha: 0.70),
                    ],
                  ),
                ),
              ),
            ),
            GlassScaffold(
              contentAwareBrightness: true,
              backgroundColor: Colors.transparent,
              appBar: GlassAppBar(
                leading: GlassIconButton(
                  icon: const Icon(CupertinoIcons.chevron_down),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  metadata.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Image 3 Apple Karaoke Top Bar: 44x44 cover thumbnail + title/artist + star + more
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
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
                PositionSlider(metadata: metadata),
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

    return ValueListenableBuilder<List>(
      valueListenable: isRadioStation ? userLikedRadioStations : userLikedSongsList,
      builder: (context, _, __) {
        final isLiked = isRadioStation
            ? isRadioStationLiked(audioId ?? '')
            : isSongAlreadyLiked(audioId);
        return CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            if (audioId == null) return;
            HapticFeedback.lightImpact();
            if (isRadioStation) {
              if (isLiked) {
                await removeRadioStationFromLiked(audioId);
              } else {
                await addRadioStationToLiked(audioId);
              }
            } else {
              await updateSongLikeStatus(audioId, !isLiked, songData: mediaItemToMap(metadata));
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
              isLiked ? CupertinoIcons.star_fill : CupertinoIcons.star,
              size: 18,
              color: isLiked ? const Color(0xFFFF2D55) : CupertinoColors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreButton(BuildContext context, MediaItem metadata) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _showMoreSheet(context, metadata),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: CupertinoColors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          CupertinoIcons.ellipsis,
          size: 18,
          color: CupertinoColors.white,
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, MediaItem metadata) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: Text(metadata.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        message: Text(metadata.artist ?? ''),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showAddToPlaylistDialog(context, songs: [mediaItemToMap(metadata)]);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus_rectangle_on_rectangle),
                SizedBox(width: 8),
                Text('Add to Playlist'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final audioId = metadata.extras?['ytid']?.toString();
              if (audioId == null) return;
              if (isSongAlreadyOffline(audioId)) {
                await OfflinePlaylistService().removeSongFromOfflineAndResync(audioId);
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSongAlreadyOffline(metadata.extras?['ytid']?.toString())
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.arrow_down_circle,
                ),
                const SizedBox(width: 8),
                Text(
                  isSongAlreadyOffline(metadata.extras?['ytid']?.toString())
                      ? 'Downloaded (Tap to Remove)'
                      : 'Download for Offline',
                ),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              showSleepTimerDialog(context);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.timer),
                SizedBox(width: 8),
                Text('Sleep Timer'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
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
            size: 54,
            iconColor: CupertinoColors.white,
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
