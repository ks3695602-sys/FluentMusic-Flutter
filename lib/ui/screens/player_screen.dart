import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/audio/audio_handler.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../core/lyrics/synced_line.dart';

class PlayerScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const PlayerScreen({super.key, required this.audioHandler});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final LyricsService _lyricsService = LyricsService();
  final LyricController _lyricController = LyricController();

  bool _hasLyrics = false;
  bool _showLyrics = false;
  String _currentTrackId = '';

  @override
  void initState() {
    super.initState();
    _fetchLyricsForCurrentTrack();
  }

  @override
  void dispose() {
    _lyricController.dispose();
    super.dispose();
  }

  void _fetchLyricsForCurrentTrack() async {
    final item = widget.audioHandler.mediaItem.value;
    if (item == null || item.id == _currentTrackId) return;
    _currentTrackId = item.id;

    final lines = await _lyricsService.fetchLyrics(
      trackName: item.title,
      artistName: item.artist ?? '',
      duration: item.duration ?? Duration.zero,
    );

    if (mounted) {
      if (lines.isNotEmpty) {
        // Construct standard LRC string for flutter_lyric
        final StringBuffer sb = StringBuffer();
        for (final l in lines) {
          final m = l.time.inMinutes.toString().padLeft(2, '0');
          final s = (l.time.inSeconds % 60).toString().padLeft(2, '0');
          final ms = ((l.time.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
          sb.writeln('[$m:$s.$ms]${l.text}');
        }
        _lyricController.load(sb.toString());
        setState(() => _hasLyrics = true);
      } else {
        setState(() => _hasLyrics = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: widget.audioHandler.mediaItem,
      builder: (context, mediaSnapshot) {
        final item = mediaSnapshot.data;
        if (item != null && item.id != _currentTrackId) {
          _fetchLyricsForCurrentTrack();
        }

        return Scaffold(
          backgroundColor: Colors.black, // Pure OLED Black
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Subtle Ambient Album Glow Backdrop
              if (item?.artUri != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.22,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: CachedNetworkImage(
                        imageUrl: item!.artUri.toString(),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),

              // 2. Main Content
              SafeArea(
                child: Column(
                  children: [
                    // Top App Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GlassIconButton(
                            icon: const Icon(CupertinoIcons.chevron_down, color: Colors.white, size: 22),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          Column(
                            children: [
                              Text(
                                'PLAYING FROM PLAYLIST',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              const Text(
                                'FluentMusic',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          GlassIconButton(
                            icon: Icon(
                              _showLyrics ? CupertinoIcons.quote_bubble_fill : CupertinoIcons.quote_bubble,
                              color: _showLyrics ? const Color(0xFFFA2D48) : Colors.white70,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _showLyrics = !_showLyrics),
                          ),
                        ],
                      ),
                    ),

                    // Middle: Artwork OR flutter_lyric synced karaoke
                    Expanded(
                      child: _showLyrics ? _buildLyricsView() : _buildArtworkView(item),
                    ),

                    // Bottom Controls Platter
                    _buildBottomControls(item),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArtworkView(MediaItem? item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36.0, vertical: 20.0),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: item?.artUri != null
                  ? CachedNetworkImage(
                      imageUrl: item!.artUri.toString(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white12,
                        child: const Icon(CupertinoIcons.music_note, size: 80, color: Colors.white24),
                      ),
                    )
                  : Container(
                      color: Colors.white12,
                      child: const Icon(CupertinoIcons.music_note, size: 80, color: Colors.white24),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    if (!_hasLyrics) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.quote_bubble, size: 48, color: Colors.white30),
            const SizedBox(height: 12),
            Text(
              'No lyrics found for this song',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.audioHandler.player.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;
        _lyricController.setPosition(position);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LyricView(
              controller: _lyricController,
              preset: LyricPresets.appleMusic,
              onLineTap: (line) {
                widget.audioHandler.seek(line.seekPosition);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls(MediaItem? item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
      child: Column(
        children: [
          // Track Info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item?.title ?? 'No Track Playing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item?.artist ?? 'FluentMusic',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.heart, color: Colors.white70, size: 26),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Seeker Slider with Apple Red Accent
          StreamBuilder<Duration>(
            stream: widget.audioHandler.player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = widget.audioHandler.player.duration ?? Duration.zero;
              final max = duration.inMilliseconds > 0 ? duration.inMilliseconds.toDouble() : 1.0;
              final current = position.inMilliseconds.toDouble().clamp(0.0, max);

              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3.5,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
                      activeTrackColor: const Color(0xFFFA2D48), // Apple Red
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFFFA2D48).withValues(alpha: 0.2),
                    ),
                    child: Slider(
                      value: current,
                      min: 0.0,
                      max: max,
                      onChanged: (val) {
                        widget.audioHandler.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                        Text(
                          _formatDuration(duration),
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // Playback Buttons Capsule
          StreamBuilder<PlaybackState>(
            stream: widget.audioHandler.playbackState,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.shuffle, color: Colors.white54, size: 22),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.backward_fill, color: Colors.white, size: 34),
                    onPressed: () => widget.audioHandler.skipToPrevious(),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (playing) {
                        widget.audioHandler.pause();
                      } else {
                        widget.audioHandler.play();
                      }
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 34,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.forward_fill, color: Colors.white, size: 34),
                    onPressed: () => widget.audioHandler.skipToNext(),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.repeat, color: Colors.white54, size: 22),
                    onPressed: () {},
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
