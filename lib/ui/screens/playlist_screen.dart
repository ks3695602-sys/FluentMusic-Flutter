import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../widgets/mini_player_bar.dart';

class PlaylistScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;
  final String coverUrl;
  final List<MediaTrack> tracks;
  final FluentAudioHandler audioHandler;

  const PlaylistScreen({
    super.key,
    required this.title,
    this.subtitle = 'Apple Music Editorial',
    this.description = 'The best curated tracks. Updated regularly in lossless streaming.',
    required this.coverUrl,
    required this.tracks,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      background: const ColoredBox(color: Colors.black),
      contentAwareBrightness: true,
      bottomBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: MiniPlayerBar(audioHandler: audioHandler),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. Top Glass App Bar with Back, Share, and More (Image 4)
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Center(
                child: GlassIconButton(
                  icon: const Icon(CupertinoIcons.chevron_left, color: Colors.white, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            actions: [
              GlassIconButton(
                icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: const Icon(CupertinoIcons.ellipsis, color: Colors.white, size: 20),
                onPressed: () {},
              ),
              const SizedBox(width: 14),
            ],
          ),

          // 2. Hero Header with Ambient Blur (Image 4)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Cover Artwork with Ambient Drop Glow
                  Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFA2D48).withOpacity(0.28),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: coverUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: coverUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white12,
                                  child: const Icon(CupertinoIcons.music_note_list,
                                      size: 72, color: Colors.white30),
                                ),
                              )
                            : Container(
                                color: Colors.white12,
                                child: const Icon(CupertinoIcons.music_note_list,
                                    size: 72, color: Colors.white30),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFA2D48), // Apple Red
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.6),
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 3. Action Buttons Capsule Row (Image 4: Shuffle, Play, +)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Shuffle Capsule
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (tracks.isNotEmpty) {
                              final shuffled = List<MediaTrack>.from(tracks)..shuffle();
                              audioHandler.playTrack(shuffled.first, queue: shuffled);
                            }
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(23),
                              color: Colors.white.withOpacity(0.12),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.18),
                                width: 1.0,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.shuffle, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Shuffle',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Solid White Play Capsule (Image 4)
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (tracks.isNotEmpty) {
                              audioHandler.playTrack(tracks.first, queue: tracks);
                            }
                          },
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(23),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.play_fill, color: Colors.black, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Play',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Add '+' Capsule Button
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.18),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(CupertinoIcons.add, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),

          // 4. Track List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: track.artUri.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: track.artUri,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: Colors.white10,
                                        child: const Icon(CupertinoIcons.music_note,
                                            size: 20, color: Colors.white30),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(CupertinoIcons.music_note,
                                          size: 20, color: Colors.white30),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 13,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(CupertinoIcons.ellipsis, color: Colors.white54, size: 20),
                        onPressed: () {},
                      ),
                      onTap: () {
                        audioHandler.playTrack(track, queue: tracks);
                      },
                    ),
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
