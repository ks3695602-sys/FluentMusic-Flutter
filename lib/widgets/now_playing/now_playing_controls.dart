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

import 'package:audio_service/audio_service.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/widgets/glass/glass_toast.dart';
import 'package:musify/widgets/now_playing/bottom_actions_row.dart';
import 'package:musify/widgets/now_playing/marquee_text_widget.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';
import 'package:musify/widgets/now_playing/song_like_button.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 24,
                vertical: spacing,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => _copyNowPlayingSong(context, metadata),
                          child: MarqueeTextWidget(
                            text: metadata.title,
                            fontColor: CupertinoColors.white,
                            fontSize: titleFontSize * fontScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (metadata.artist != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: canOpenArtist
                                ? () => _openArtistPage(context, metadata)
                                : null,
                            onLongPress: () => _copyNowPlayingSong(context, metadata),
                            child: MarqueeTextWidget(
                              text: metadata.artist!,
                              fontColor: CupertinoColors.white.withValues(alpha: 0.7),
                              fontSize: artistFontSize * fontScale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SongLikeButton(
                    songId: audioId?.toString(),
                    songData: mediaItemToMap(metadata),
                    iconSize: 24,
                    minSize: 38,
                  ),
                  GlassPullDownButton(
                    icon: Icon(
                      CupertinoIcons.ellipsis,
                      color: CupertinoColors.white.withValues(alpha: 0.9),
                      size: 20,
                    ),
                    semanticLabel: 'More options',
                    buttonWidth: 38,
                    buttonHeight: 38,
                    menuWidth: 248,
                    items: [
                      GlassMenuItem(
                        title: 'Add to Playlist',
                        subtitle: 'Choose or create a playlist',
                        icon: const Icon(
                          CupertinoIcons.plus_rectangle_on_rectangle,
                        ),
                        onTap: () => showAddToPlaylistDialog(
                          context,
                          songs: [mediaItemToMap(metadata)],
                        ),
                      ),
                      GlassMenuItem(
                        title: isSongAlreadyOffline(
                          metadata.extras?['ytid']?.toString(),
                        )
                            ? 'Remove Download'
                            : 'Download for Offline',
                        subtitle: isSongAlreadyOffline(
                          metadata.extras?['ytid']?.toString(),
                        )
                            ? 'Free up local storage'
                            : 'Keep this song available offline',
                        icon: Icon(
                          isSongAlreadyOffline(
                                metadata.extras?['ytid']?.toString(),
                              )
                              ? CupertinoIcons.check_mark_circled_solid
                              : CupertinoIcons.arrow_down_circle,
                        ),
                        onTap: () async {
                          final audioId =
                              metadata.extras?['ytid']?.toString();
                          if (audioId == null) return;
                          if (isSongAlreadyOffline(audioId)) {
                            await OfflinePlaylistService()
                                .removeSongFromOfflineAndResync(audioId);
                            if (context.mounted) {
                              showToast(
                                context,
                                'Removed from offline storage',
                              );
                            }
                          } else {
                            final success = await makeSongOffline(
                              mediaItemToMap(metadata),
                            );
                            if (context.mounted && success) {
                              showToast(
                                context,
                                'Downloaded for offline playback',
                              );
                            }
                          }
                        },
                      ),
                      GlassMenuItem(
                        title: 'Sleep Timer',
                        subtitle: 'Stop playback after a delay',
                        icon: const Icon(CupertinoIcons.timer),
                        onTap: () => showSleepTimerDialog(context),
                      ),
                      if (_canOpenArtist(metadata))
                        GlassMenuItem(
                          title: 'Go to Artist',
                          icon: const Icon(
                            CupertinoIcons.person_crop_circle,
                          ),
                          onTap: () => _openArtistPage(context, metadata),
                        ),
                      GlassMenuItem(
                        title: 'Copy Title & Artist',
                        icon: const Icon(CupertinoIcons.doc_on_doc),
                        onTap: () => _copyNowPlayingSong(context, metadata),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.speaker_fill,
                    size: 14,
                    color: CupertinoColors.white.withValues(alpha: 0.38),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3.0,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.0, elevation: 1.0),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 10.0),
                        activeTrackColor: CupertinoColors.white,
                        inactiveTrackColor: CupertinoColors.white.withValues(alpha: 0.18),
                        thumbColor: CupertinoColors.white,
                      ),
                      child: StreamBuilder<double>(
                        stream: audioHandler.volumeStream,
                        initialData: audioHandler.volume,
                        builder: (context, volSnap) {
                          final vol = volSnap.data ?? 1.0;
                          return Slider(
                            value: vol.clamp(0.0, 1.0),
                            onChanged: (val) async {
                              final wasZero = vol <= 0.001;
                              await audioHandler.setVolume(val);
                              if (!context.mounted) return;
                              final isPlaying =
                                  audioHandler.playbackState.value.playing;
                              if (val <= 0.001 &&
                                  pauseOnVolumeZero.value &&
                                  isPlaying) {
                                await audioHandler.pause();
                              } else if (wasZero &&
                                  val > 0.001 &&
                                  resumeOnVolumeRaise.value &&
                                  !isPlaying) {
                                await audioHandler.play();
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Icon(
                    CupertinoIcons.speaker_3_fill,
                    size: 16,
                    color: CupertinoColors.white.withValues(alpha: 0.38),
                  ),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    return !offlineMode.value &&
        (info.artist.isNotEmpty ||
            info.artistId.isNotEmpty ||
            info.sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final info = _extractArtistInfo(metadata);
    final lookup = info.artistId.isNotEmpty
        ? info.artistId
        : info.artist.isNotEmpty
        ? info.artist
        : info.sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final artistPath = NavigationManager.artistPath(context, lookup);
    final artistData = {
      'ytid': info.artistId.isNotEmpty ? info.artistId : lookup,
      if (info.artist.isNotEmpty) 'title': info.artist,
      if (info.sourceSongId.isNotEmpty) 'sourceSongId': info.sourceSongId,
      if (info.videoAuthor.isNotEmpty) 'videoAuthor': info.videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(router.push(artistPath, extra: artistData));
  }

  ({String artist, String artistId, String sourceSongId, String videoAuthor})
  _extractArtistInfo(MediaItem metadata) {
    return (
      artist: metadata.artist?.trim() ?? '',
      artistId: metadata.extras?['artistId']?.toString().trim() ?? '',
      sourceSongId: metadata.extras?['ytid']?.toString().trim() ?? '',
      videoAuthor: metadata.extras?['videoAuthor']?.toString().trim() ?? '',
    );
  }
}

Future<void> _copyNowPlayingSong(
  BuildContext context,
  MediaItem metadata,
) async {
  final artist = metadata.artist?.trim();
  final title = metadata.title.trim();
  final text = artist == null || artist.isEmpty ? title : '$artist - $title';
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showToast(context, context.l10n!.songInfoCopied);
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        final buttonSpacing = isUltraTight
            ? 6.0
            : isTight
            ? 10.0
            : screenWidth < 360
            ? 8.0
            : 16.0;
        final minButtonSize = isUltraTight
            ? 38.0
            : isTight
            ? 42.0
            : 46.0;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        final buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: _PlaybackControlsRow(
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    buttonSpacing: buttonSpacing,
                    minButtonSize: minButtonSize,
                    playPadding: playPadding,
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return GlassIconButton(
          icon: Icon(
            CupertinoIcons.shuffle,
            size: 18,
            color: value
                ? const Color(0xFFFF2D55)
                : CupertinoColors.white.withValues(alpha: 0.75),
          ),
          onPressed: () {
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            final isActive = repeatMode != AudioServiceRepeatMode.none;

            return GlassIconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? CupertinoIcons.repeat_1
                    : CupertinoIcons.repeat,
                size: 18,
                color: isActive
                    ? const Color(0xFFFF2D55)
                    : CupertinoColors.white.withValues(alpha: 0.75),
              ),
              onPressed: () {
                final AudioServiceRepeatMode newMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  newMode = queue.length <= 1
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                repeatNotifier.value = newMode;
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        );
      },
    );
  }
}

class _PlaybackControlsRow extends StatelessWidget {
  const _PlaybackControlsRow({
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.buttonSpacing,
    required this.minButtonSize,
    required this.playPadding,
  });

  final ColorScheme colorScheme;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double buttonSpacing;
  final double minButtonSize;
  final EdgeInsets playPadding;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlaybackControlButton(
                    icon: CupertinoIcons.backward_fill,
                    isEnabled:
                        audioHandler.hasPrevious ||
                        repeatMode != AudioServiceRepeatMode.none,
                    tooltip: context.l10n!.skipToPrevious,
                    onPressed: () => audioHandler.skipToPrevious(),
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                  SizedBox(width: buttonSpacing),
                  PlaybackIconButton(
                    iconColor: CupertinoColors.black,
                    backgroundColor: CupertinoColors.white,
                    iconSize: controlIconSize,
                    padding: playPadding,
                  ),
                  SizedBox(width: buttonSpacing),
                  _PlaybackControlButton(
                    icon: CupertinoIcons.forward_fill,
                    isEnabled:
                        audioHandler.hasNext ||
                        repeatMode == AudioServiceRepeatMode.one,
                    tooltip: context.l10n!.skipToNext,
                    onPressed: () => repeatMode == AudioServiceRepeatMode.one
                        ? audioHandler.playAgain()
                        : audioHandler.skipToNext(),
                    colorScheme: colorScheme,
                    buttonConstraints: buttonConstraints,
                    buttonPadding: buttonPadding,
                    controlIconSize: controlIconSize,
                    minButtonSize: minButtonSize,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaybackControlButton extends StatelessWidget {
  const _PlaybackControlButton({
    required this.icon,
    required this.isEnabled,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
    required this.buttonConstraints,
    required this.buttonPadding,
    required this.controlIconSize,
    required this.minButtonSize,
  });

  final IconData icon;
  final bool isEnabled;
  final String tooltip;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;
  final BoxConstraints buttonConstraints;
  final EdgeInsets buttonPadding;
  final double controlIconSize;
  final double minButtonSize;

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icon(
        icon,
        color: isEnabled
            ? CupertinoColors.white
            : CupertinoColors.white.withValues(alpha: 0.3),
        size: controlIconSize * 0.72,
      ),
      onPressed: isEnabled ? onPressed : null,
    );
  }
}
