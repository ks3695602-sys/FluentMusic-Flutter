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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/main.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/playlist_dialogs.dart';

/// Tag kept in one place so the Explore rail and the viewer can share it.
String shortsHeroTagFor(Map song) => 'explore-shorts-${song['ytid']}';

/// Full-screen, vertically paged Shorts previews.
///
/// The preview streams the normal full track and pauses at a per-song limit
/// between 15 and 30 seconds. Closing pauses the preview; "Play Full Song"
/// upgrades the same buffered stream and closes the viewer.
class ShortsViewerPage extends StatefulWidget {
  const ShortsViewerPage({
    required this.songs,
    required this.initialIndex,
    super.key,
  });

  final List<Map<String, dynamic>> songs;
  final int initialIndex;

  /// Opens the viewer on the root navigator so it covers the dock too.
  ///
  /// [fromRect] is the tapped card in global coordinates. When supplied, the
  /// route expands from that rect into the full screen, giving the rail a
  /// shared-element feel without relying on heroes across nested navigators.
  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> songs,
    int initialIndex = 0,
    Rect? fromRect,
  }) {
    if (songs.isEmpty) return Future.value();
    final safeIndex = initialIndex < 0
        ? 0
        : (initialIndex >= songs.length ? songs.length - 1 : initialIndex);

    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) =>
            ShortsViewerPage(songs: songs, initialIndex: safeIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          if (fromRect == null) {
            return FadeTransition(opacity: curved, child: child);
          }

          final size = MediaQuery.sizeOf(context);
          return AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final t = curved.value;
              final rect =
                  Rect.lerp(fromRect, Offset.zero & size, t) ??
                  (Offset.zero & size);
              return Opacity(
                opacity: 0.4 + 0.6 * t,
                child: Transform(
                  alignment: Alignment.topLeft,
                  transform: Matrix4.diagonal3Values(
                    rect.width / size.width,
                    rect.height / size.height,
                    1,
                  )..setTranslationRaw(rect.left, rect.top, 0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  State<ShortsViewerPage> createState() => _ShortsViewerPageState();
}

class _ShortsViewerPageState extends State<ShortsViewerPage> {
  late final PageController _pageController = PageController(
    initialPage: _safeInitialIndex,
  );
  late int _index = _safeInitialIndex;

  bool _loading = false;
  bool _failed = false;
  bool _closed = false;
  bool _upgraded = false;
  int _previewRequest = 0;

  int get _safeInitialIndex => widget.initialIndex < 0
      ? 0
      : (widget.initialIndex >= widget.songs.length
            ? widget.songs.length - 1
            : widget.initialIndex);

  Map<String, dynamic> get _song => widget.songs[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startPreview();
    });
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_pausePreviewIfNeeded());
    _pageController.dispose();
    super.dispose();
  }

  Duration _previewDuration(Map<String, dynamic> song) {
    final seed = (song['ytid']?.toString() ?? '').hashCode & 0x7fffffff;
    return Duration(seconds: 15 + seed % 16);
  }

  Future<void> _startPreview() async {
    final song = _song;
    final requestId = ++_previewRequest;
    setState(() {
      _loading = true;
      _failed = false;
    });

    final success = await audioHandler.playPreviewSong(
      song,
      maxDuration: _previewDuration(song),
    );

    if (!mounted || _closed || requestId != _previewRequest) {
      // A stale preview must not keep playing over a newer page or after close.
      if (success && _isCurrentSong(song)) {
        unawaited(audioHandler.pause());
      }
      return;
    }

    setState(() {
      _loading = false;
      _failed = !success;
    });
  }

  bool _isCurrentSong(Map<String, dynamic> song) {
    // Preview playback swaps the media item but leaves the queue untouched, so
    // the media item is the only reliable source for "what is loaded".
    return audioHandler.mediaItem.valueOrNull?.extras?['ytid']?.toString() ==
        song['ytid']?.toString();
  }

  Future<void> _pausePreviewIfNeeded() async {
    if (_upgraded) return;
    final item = audioHandler.mediaItem.valueOrNull;
    if (item?.extras?['isPreview'] != true) return;
    await audioHandler.pause();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    unawaited(_pausePreviewIfNeeded());
    Navigator.of(context).pop();
  }

  Future<void> _playFullSong() async {
    final song = _song;
    if (_isCurrentSong(song)) {
      _upgraded = true;
      await audioHandler.playFullSong();
    } else {
      final success = await audioHandler.playSong(song);
      if (!success) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      _upgraded = true;
    }

    if (!mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      _failed = false;
      _upgraded = false;
    });
    unawaited(_startPreview());
  }

  Future<void> _togglePlayback() async {
    if (_loading) return;
    if (!_isCurrentSong(_song)) {
      await _startPreview();
      return;
    }

    if (audioHandler.audioPlayer.playing) {
      await audioHandler.pause();
    } else {
      await audioHandler.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    final song = _song;
    final id = song['ytid']?.toString();
    if (id == null || id.isEmpty) return;
    final liked = isSongAlreadyLiked(id);
    await updateSongLikeStatus(id, !liked, songData: song);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final topPadding = MediaQuery.paddingOf(context).top;
    final category = _song['exploreCategory']?.toString().trim() ?? '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: CupertinoColors.transparent,
        systemNavigationBarColor: CupertinoColors.black,
      ),
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) unawaited(_pausePreviewIfNeeded());
        },
        child: ColoredBox(
          color: CupertinoColors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.songs.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _ShortsBackdrop(song: widget.songs[index]);
                },
              ),
              Positioned(
                top: topPadding + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    GlassIconButton(
                      icon: const Icon(
                        CupertinoIcons.xmark,
                        color: CupertinoColors.white,
                      ),
                      settings: LiquidGlassSettings.classicDark,
                      size: 42,
                      iconSize: 18,
                      onPressed: _close,
                      semanticLabel: 'Close shorts',
                    ),
                    const Spacer(),
                    if (category.isNotEmpty)
                      _CategoryBadge(label: category),
                  ],
                ),
              ),
              Center(
                child: _loading
                    ? const CupertinoTheme(
                        data: CupertinoThemeData(brightness: Brightness.dark),
                        child: CupertinoActivityIndicator(radius: 17),
                      )
                    : StreamBuilder<PlaybackState>(
                        stream: audioHandler.playbackStateStream,
                        initialData: audioHandler.playbackState.valueOrNull,
                        builder: (context, snapshot) {
                          final playing = snapshot.data?.playing ?? false;
                          return GlassIconButton(
                            icon: Icon(
                              playing
                                  ? FluentIcons.pause_24_regular
                                  : FluentIcons.play_24_filled,
                              color: CupertinoColors.white,
                            ),
                            settings: LiquidGlassSettings.classicDark,
                            size: 64,
                            iconSize: 26,
                            onPressed: _togglePlayback,
                            semanticLabel: playing ? 'Pause preview' : 'Play preview',
                          );
                        },
                      ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomPadding + 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewProgress(
                      positionStream: audioHandler.positionDataStream,
                      song: _song,
                      limit: _previewDuration(_song),
                    ),
                    const SizedBox(height: 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        key: ValueKey(_song['ytid']?.toString() ?? _index),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _song['title']?.toString() ?? 'Unknown title',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _song['artist']?.toString() ?? 'Unknown artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.72,
                              ),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_failed) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            FluentIcons.warning_24_regular,
                            color: CupertinoColors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Preview unavailable. Tap Play Full Song.',
                            style: TextStyle(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.72,
                              ),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    ValueListenableBuilder<List>(
                      valueListenable: userLikedSongsList,
                      builder: (context, _, __) {
                        final id = _song['ytid']?.toString() ?? '';
                        final liked = id.isNotEmpty && isSongAlreadyLiked(id);
                        return Row(
                          children: [
                            GlassIconButton(
                              icon: Icon(
                                liked
                                    ? FluentIcons.heart_24_filled
                                    : FluentIcons.heart_24_regular,
                                color: liked
                                    ? const Color(0xFFFF375F)
                                    : CupertinoColors.white,
                              ),
                              settings: LiquidGlassSettings.classicDark,
                              size: 46,
                              iconSize: 21,
                              onPressed: _toggleLike,
                              semanticLabel: liked ? 'Unlike' : 'Like',
                            ),
                            const SizedBox(width: 10),
                            GlassIconButton(
                              icon: const Icon(
                                FluentIcons.save_20_regular,
                                color: CupertinoColors.white,
                              ),
                              settings: LiquidGlassSettings.classicDark,
                              size: 46,
                              iconSize: 20,
                              onPressed: () => showAddToPlaylistDialog(
                                context,
                                song: _song,
                              ),
                              semanticLabel: 'Save to playlist',
                            ),
                            const Spacer(),
                            GlassButton.custom(
                              onTap: _playFullSong,
                              height: 46,
                              width: 176,
                              shape: const LiquidRoundedRectangle(
                                borderRadius: 23,
                              ),
                              settings: LiquidGlassSettings.classicDark,
                              glowColor: CupertinoColors.black,
                              glowRadius: 16,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    FluentIcons.play_24_filled,
                                    color: CupertinoColors.white,
                                    size: 17,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    'Play Full Song',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortsBackdrop extends StatelessWidget {
  const _ShortsBackdrop({required this.song});

  final Map<String, dynamic> song;

  @override
  Widget build(BuildContext context) {
    final image = (song['highResImage'] ??
            song['image'] ??
            song['lowResImage'])
        ?.toString();

    return Stack(
      fit: StackFit.expand,
      children: [
        if (image == null || image.isEmpty)
          const ColoredBox(
            color: CupertinoColors.black,
            child: Center(
              child: Icon(
                FluentIcons.music_note_2_24_regular,
                color: CupertinoColors.white,
                size: 56,
              ),
            ),
          )
        else
          CachedNetworkImage(
            imageUrl: image,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 220),
            placeholder: (_, __) => const ColoredBox(
              color: CupertinoColors.black,
            ),
            errorWidget: (_, __, ___) => const ColoredBox(
              color: CupertinoColors.black,
              child: Center(
                child: Icon(
                  FluentIcons.music_note_2_24_regular,
                  color: CupertinoColors.white,
                  size: 56,
                ),
              ),
            ),
          ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66000000),
                Color(0x00000000),
                Color(0x22000000),
                Color(0xD9000000),
              ],
              stops: [0.0, 0.3, 0.58, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: CupertinoColors.white.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: CupertinoColors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _PreviewProgress extends StatelessWidget {
  const _PreviewProgress({
    required this.positionStream,
    required this.song,
    required this.limit,
  });

  final Stream<PositionData> positionStream;
  final Map<String, dynamic> song;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: positionStream,
      initialData: audioHandler.currentPositionData,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final isCurrent =
            audioHandler.mediaItem.valueOrNull?.extras?['ytid']?.toString() ==
            song['ytid']?.toString();
        final fraction = isCurrent && data != null
            ? (data.position.inMilliseconds / limit.inMilliseconds)
                  .clamp(0.0, 1.0)
                  .toDouble()
            : 0.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: CupertinoColors.white.withValues(alpha: 0.22),
                ),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: const ColoredBox(color: CupertinoColors.white),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
