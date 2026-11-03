import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/audio/audio_models.dart';
import 'liquid_glass_container.dart';

class LiquidGlassCard extends StatelessWidget {
  final MediaTrack track;
  final VoidCallback onTap;
  final double width;

  const LiquidGlassCard({
    super.key,
    required this.track,
    required this.onTap,
    this.width = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art with Liquid Glass play button
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: track.artUri.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: track.artUri,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: const Color(0xFF1E2130),
                              child: const Icon(Icons.music_note, color: Colors.white24, size: 40),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: const Color(0xFF1E2130),
                              child: const Icon(Icons.music_note, color: Colors.white24, size: 40),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF1E2130),
                            child: const Icon(Icons.music_note, color: Colors.white24, size: 40),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: LiquidGlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(8.0),
                    tintColor: Colors.black.withValues(alpha: 0.45),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2.0),
            Text(
              track.artist,
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
    );
  }
}
