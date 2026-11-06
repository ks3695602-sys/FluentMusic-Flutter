import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../../core/innertube/innertube_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/liquid_glass_container.dart';

class NewScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const NewScreen({super.key, required this.audioHandler});

  @override
  State<NewScreen> createState() => _NewScreenState();
}

class _NewScreenState extends State<NewScreen> {
  final InnertubeService _innertubeService = InnertubeService();
  Map<String, List<MediaTrack>> _feed = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNewFeed();
  }

  Future<void> _loadNewFeed() async {
    setState(() => _isLoading = true);
    final data = await _innertubeService.getNewReleasesFeed();
    if (mounted) {
      setState(() {
        _feed = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFA2D48)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNewFeed,
      color: const Color(0xFFFA2D48),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // Header
          Row(
            children: [
              const Text(
                'New & Trending',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFA2D48).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFA2D48), width: 1),
                ),
                child: const Text(
                  'GLOBAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Color(0xFFFA2D48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Genre Radar Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildGenreChip('Top 50', Icons.trending_up),
                _buildGenreChip('New Drops', Icons.album),
                _buildGenreChip('Viral Reels', Icons.local_fire_department),
                _buildGenreChip('Pop', Icons.audiotrack),
                _buildGenreChip('Hip-Hop', Icons.mic),
                _buildGenreChip('Lo-Fi', Icons.nightlight_round),
                _buildGenreChip('Bollywood', Icons.stars),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Dynamic Sections
          for (final entry in _feed.entries) ...[
            _buildSection(entry.key, entry.value),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildGenreChip(String label, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: LiquidGlassContainer(
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        tintColor: Colors.white.withOpacity(0.08),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFFFA2D48)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<MediaTrack> tracks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Explore',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return LiquidGlassCard(
                track: track,
                onTap: () {
                  widget.audioHandler.playTrack(track, queue: tracks);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
