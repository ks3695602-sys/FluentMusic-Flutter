import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../../core/audio/audio_handler.dart';
import '../screens/player_screen.dart';
import 'liquid_glass_container.dart';

class MiniPlayerBar extends StatelessWidget {
  final FluentAudioHandler audioHandler;

  const MiniPlayerBar({super.key, required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, playStateSnapshot) {
            final playing = playStateSnapshot.data?.playing ?? false;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
              child: LiquidGlassContainer(
                borderRadius: 22,
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                tintColor: const Color(0xFF1E2130).withValues(alpha: 0.65),
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          PlayerScreen(audioHandler: audioHandler),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: Row(
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: mediaItem.artUri != null
                            ? CachedNetworkImage(
                                imageUrl: mediaItem.artUri.toString(),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.music_note, color: Colors.white54),
                                ),
                              )
                            : Container(
                                color: Colors.white10,
                                child: const Icon(Icons.music_note, color: Colors.white54),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 18,
                            child: mediaItem.title.length > 28
                                ? Marquee(
                                    text: mediaItem.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    blankSpace: 20.0,
                                    velocity: 30.0,
                                  )
                                : Text(
                                    mediaItem.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            mediaItem.artist ?? 'Unknown Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play / Pause Button
                    IconButton(
                      icon: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () {
                        if (playing) {
                          audioHandler.pause();
                        } else {
                          audioHandler.play();
                        }
                      },
                    ),

                    // Skip Next Button
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                      onPressed: () => audioHandler.skipToNext(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
