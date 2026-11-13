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

import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:material_ui/material_ui.dart';
import 'package:musify/main.dart';
import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/widgets/marquee.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:rxdart/rxdart.dart';

final Stream<FullPlayerState> _fullPlayerStateStream =
    Rx.combineLatest3(
          audioHandler.playbackStateStream,
          audioHandler.queue.distinct(),
          audioHandler.positionDataStream,
          (PlaybackState state, List<MediaItem> queue, PositionData pos) =>
              FullPlayerState(
                playbackState: state,
                queue: queue,
                position: pos,
              ),
        )
        .throttleTime(const Duration(milliseconds: 120), trailing: true)
        .asBroadcastStream();

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  static const double playerHeight = 56;
  static const double _borderRadius = 28;
  static const double _artworkSize = 40;
  static const double _artworkRadius = 10;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              final hasNext =
                  state.queue.length > 1 &&
                  (state.playbackState.queueIndex ?? 0) <
                      state.queue.length - 1;

              return _MiniPlayerBody(
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
                hasNext: hasNext,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    required this.colorScheme,
    required this.metadata,
    required this.state,
    required this.hasNext,
  });

  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;
  final bool hasNext;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const double _dragThresholdForNavigation = 10;

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      _navigateToNowPlaying();
    }
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;

    final totalDuration = state.position.duration > Duration.zero
        ? state.position.duration
        : (metadata.duration ?? Duration.zero);
    final progress = totalDuration.inMilliseconds == 0
        ? 0.0
        : (state.position.position.inMilliseconds /
                  totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: GestureDetector(
              onTapDown: (_) => _animationController.forward(),
              onTapUp: (_) => _animationController.reverse(),
              onTapCancel: () => _animationController.reverse(),
              onVerticalDragUpdate: _handleVerticalDrag,
              child: GestureDetector(
                onTap: _navigateToNowPlaying,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: MiniPlayer.playerHeight,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF242426).withValues(alpha: 0.88)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(MiniPlayer._borderRadius),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? CupertinoColors.white.withValues(alpha: 0.14)
                          : CupertinoColors.black.withValues(alpha: 0.08),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.08,
                        ),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        _ArtworkWidget(metadata: metadata),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeIn,
                            switchOutCurve: Curves.easeOut,
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    ...previousChildren,
                                    if (currentChild != null) currentChild,
                                  ],
                                ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(opacity: animation, child: child),
                            child: KeyedSubtree(
                              key: ValueKey(metadata.id),
                              child: _MetadataWidget(
                                title: metadata.title,
                                artist: metadata.artist,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ),
                        ),
                        _ControlsWidget(
                          colorScheme: colorScheme,
                          playbackState: state.playbackState,
                          hasNext: widget.hasNext,
                          progress: progress,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Hero(
        tag: 'now_playing_artwork',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SongArtworkWidget(
            metadata: metadata,
            size: MiniPlayer._artworkSize,
            errorWidgetIconSize: 20,
            borderRadius: MiniPlayer._artworkRadius,
          ),
        ),
      ),
    );
  }
}

class _MetadataWidget extends StatelessWidget {
  const _MetadataWidget({
    required this.title,
    required this.artist,
    required this.colorScheme,
  });

  final String title;
  final String? artist;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final secondaryTextColor = isDark
        ? CupertinoColors.white.withValues(alpha: 0.65)
        : const Color(0xFF8E8E93);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (artist != null && artist!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist!,
              style: TextStyle(
                color: secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _ControlsWidget extends StatelessWidget {
  const _ControlsWidget({
    required this.colorScheme,
    required this.playbackState,
    required this.hasNext,
    required this.progress,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;
  final bool hasNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? CupertinoColors.white : const Color(0xFF1C1C1E);
    final isPlaying = playbackState.playing;
    final processingState = playbackState.processingState;
    final isLoading = processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
          )
        else
          IconButton(
            onPressed: isPlaying ? audioHandler.pause : audioHandler.play,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              isPlaying ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
              color: iconColor,
              size: 24,
            ),
          ),
        if (hasNext) ...[
          IconButton(
            onPressed: audioHandler.skipToNext,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              CupertinoIcons.forward_end_fill,
              color: iconColor.withValues(alpha: isDark ? 0.9 : 0.8),
              size: 22,
            ),
          ),
        ],
      ],
    );
  }
}


