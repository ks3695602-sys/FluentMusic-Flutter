import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../../core/innertube/innertube_service.dart';
import '../widgets/liquid_glass_card.dart';
import '../widgets/liquid_glass_container.dart';

class HomeScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const HomeScreen({super.key, required this.audioHandler});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final InnertubeService _innertubeService = InnertubeService();
  Map<String, List<MediaTrack>> _feed = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeFeed();
  }

  Future<void> _loadHomeFeed() async {
    setState(() => _isLoading = true);
    final data = await _innertubeService.getPersonalizedHomeFeed();
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
        child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomeFeed,
      color: const Color(0xFF6C5CE7),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          // App Title Banner
          Row(
            children: [
              const Text(
                'FluentMusic',
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'LIQUID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              LiquidGlassContainer(
                borderRadius: 20,
                padding: const EdgeInsets.all(8),
                tintColor: Colors.white.withValues(alpha: 0.1),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFF00CEC9), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic Feed Sections
          for (final entry in _feed.entries) ...[
            _buildSection(entry.key, entry.value),
            const SizedBox(height: 24),
          ],
        ],
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
              'See All',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
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
