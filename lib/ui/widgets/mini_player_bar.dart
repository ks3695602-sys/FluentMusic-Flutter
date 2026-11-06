import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:marquee/marquee.dart';

import '../../core/audio/audio_handler.dart';
import '../screens/player_screen.dart';

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

            return GestureDetector(
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
              child: GlassContainer(
                useOwnLayer: true,
                shape: const LiquidShape.roundedRectangle(borderRadius: 22),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Row(
                  children: [
                    // Album Art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: mediaItem.artUri != null
                            ? CachedNetworkImage(
                                imageUrl: mediaItem.artUri.toString(),
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white12,
                                  child: const Icon(
                                    CupertinoIcons.music_note,
                                    color: Colors.white54,
                                    size: 20,
                                  ),
                                ),
                              )
                            : Container(
                                color: Colors.white12,
                                child: const Icon(
                                  CupertinoIcons.music_note,
                                  color: Colors.white54,
                                  size: 20,
                                ),
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
                            child: mediaItem.title.length > 26
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
                            mediaItem.artist ?? 'FluentMusic',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Play / Pause Icon Button
                    IconButton(
                      icon: Icon(
                        playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 26,
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
                        CupertinoIcons.forward_fill,
                        color: Colors.white70,
                        size: 22,
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
