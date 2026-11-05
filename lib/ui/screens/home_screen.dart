import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../../core/innertube/innertube_service.dart';
import '../widgets/liquid_glass_card.dart';
import 'playlist_screen.dart';

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
        child: CupertinoActivityIndicator(radius: 14, color: Color(0xFFFA2D48)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHomeFeed,
      color: const Color(0xFFFA2D48),
      backgroundColor: const Color(0xFF161820),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 140),
        children: [
          // Apple Music Header: "Listen Now" (Image 2)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Listen Now',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      CupertinoIcons.person_crop_circle_fill,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Section 1: Recently Played >
          if (_feed.containsKey('Quick Picks'))
            _buildSection(
              title: 'Recently Played',
              tracks: _feed['Quick Picks']!,
              isCompact: true,
            ),

          // Section 2: Trending community playlists >
          if (_feed.containsKey('Smart Mixes'))
            _buildSection(
              title: 'Trending community playlists',
              tracks: _feed['Smart Mixes']!,
              isPlaylistCollage: true,
            ),

          // Section 3: Romance Right Now >
          if (_feed.containsKey('Forgotten Favorites'))
            _buildSection(
              title: 'Romance Right Now',
              tracks: _feed['Forgotten Favorites']!,
              isHeroBanner: true,
            ),

          // Section 4: Deep Focus & Chill >
          if (_feed.containsKey('Deep Focus & Chill'))
            _buildSection(
              title: 'Easy Evenings',
              tracks: _feed['Deep Focus & Chill']!,
            ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<MediaTrack> tracks,
    bool isCompact = false,
    bool isPlaylistCollage = false,
    bool isHeroBanner = false,
  }) {
    double listHeight = 210;
    double cardWidth = 150;

    if (isCompact) {
      listHeight = 185;
      cardWidth = 135;
    } else if (isHeroBanner) {
      listHeight = 225;
      cardWidth = 175;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Apple Music ">" Chevron
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GestureDetector(
            onTap: () {
              if (tracks.isNotEmpty) {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => PlaylistScreen(
                      title: title,
                      subtitle: 'FluentMusic Apple Curation',
                      description: 'Top selections for $title in lossless streaming.',
                      coverUrl: tracks.first.artUri,
                      tracks: tracks,
                      audioHandler: widget.audioHandler,
                    ),
                  ),
                );
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),

        // Horizontal Card Carousel
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tracks.length,
            itemBuilder: (context, index) {
              final track = tracks[index];
              return LiquidGlassCard(
                track: track,
                width: cardWidth,
                onTap: () {
                  widget.audioHandler.playTrack(track, queue: tracks);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 26),
      ],
    );
  }
}
