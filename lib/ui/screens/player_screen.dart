import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/lyrics/lyrics_service.dart';
import '../../core/lyrics/synced_line.dart';
import '../widgets/liquid_glass_container.dart';
import '../widgets/mesh_canvas.dart';

class PlayerScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const PlayerScreen({super.key, required this.audioHandler});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final LyricsService _lyricsService = LyricsService();
  final ScrollController _lyricsScrollController = ScrollController();

  List<SyncedLine> _lyrics = [];
  bool _showLyrics = false;
  String _currentTrackId = '';

  @override
  void initState() {
    super.initState();
    _fetchLyricsForCurrentTrack();
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
      setState(() => _lyrics = lines);
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
          body: MeshCanvas(
            colors: const [
              Color(0xFF6C5CE7),
              Color(0xFF00CEC9),
              Color(0xFFFD79A8),
            ],
            child: SafeArea(
              child: Column(
                children: [
                  // Top App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        LiquidGlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(8),
                          tintColor: Colors.white.withValues(alpha: 0.1),
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.white, size: 28),
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
                              'FluentMusic Mix',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        LiquidGlassContainer(
                          borderRadius: 20,
                          padding: const EdgeInsets.all(8),
                          tintColor: _showLyrics
                              ? const Color(0xFF6C5CE7).withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.1),
                          onTap: () => setState(() => _showLyrics = !_showLyrics),
                          child: Icon(
                            Icons.lyrics_rounded,
                            color: _showLyrics ? const Color(0xFF00CEC9) : Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Middle Content: Artwork OR Word-by-Word Synced Lyrics
                  Expanded(
                    child: _showLyrics ? _buildLyricsView() : _buildArtworkView(item),
                  ),

                  // Bottom Controls
                  _buildBottomControls(item),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildArtworkView(MediaItem? item) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: item?.artUri != null
                  ? CachedNetworkImage(
                      imageUrl: item!.artUri.toString(),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(Icons.music_note, size: 80, color: Colors.white38),
                      ),
                    )
                  : Container(
                      color: Colors.white10,
                      child: const Icon(Icons.music_note, size: 80, color: Colors.white38),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsView() {
    if (_lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lyrics_outlined, size: 48, color: Colors.white38),
            const SizedBox(height: 12),
            Text(
              'No lyrics found for this track',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.audioHandler.player.positionStream,
      builder: (context, posSnapshot) {
        final position = posSnapshot.data ?? Duration.zero;

        // Find active line
        int activeIndex = 0;
        for (int i = 0; i < _lyrics.length; i++) {
          if (position >= _lyrics[i].time) {
            activeIndex = i;
          } else {
            break;
          }
        }

        // Auto-scroll to center active line
        if (_lyricsScrollController.hasClients) {
          _lyricsScrollController.animateTo(
            (activeIndex * 60.0) - 120.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }

        return ListView.builder(
          controller: _lyricsScrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          itemCount: _lyrics.length,
          itemBuilder: (context, index) {
            final line = _lyrics[index];
            final isActive = index == activeIndex;

            return GestureDetector(
              onTap: () => widget.audioHandler.seek(line.time),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isActive ? 22 : 16,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive
                        ? const Color(0xFF00CEC9)
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomControls(MediaItem? item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
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
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item?.artist ?? 'Select a song to start',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 28),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Seek Bar
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
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: const Color(0xFF00CEC9),
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: const Color(0xFF00CEC9).withValues(alpha: 0.2),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

          // Playback Buttons
          StreamBuilder<PlaybackState>(
            stream: widget.audioHandler.playbackState,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shuffle_rounded, color: Colors.white60),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 38),
                    onPressed: () => widget.audioHandler.skipToPrevious(),
                  ),
                  LiquidGlassContainer(
                    borderRadius: 36,
                    padding: const EdgeInsets.all(16),
                    tintColor: Colors.white.withValues(alpha: 0.25),
                    onTap: () {
                      if (playing) {
                        widget.audioHandler.pause();
                      } else {
                        widget.audioHandler.play();
                      }
                    },
                    child: Icon(
                      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 38),
                    onPressed: () => widget.audioHandler.skipToNext(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.repeat_rounded, color: Colors.white60),
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
