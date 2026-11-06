import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/audio/audio_handler.dart';
import '../../core/audio/audio_models.dart';
import '../../core/innertube/innertube_service.dart';
import '../widgets/liquid_glass_container.dart';

class SearchScreen extends StatefulWidget {
  final FluentAudioHandler audioHandler;

  const SearchScreen({super.key, required this.audioHandler});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final InnertubeService _innertubeService = InnertubeService();
  final TextEditingController _searchController = TextEditingController();

  List<String> _suggestions = [];
  List<MediaTrack> _searchResults = [];
  bool _isSearching = false;

  void _onQueryChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final list = await _innertubeService.getSearchSuggestions(query);
    if (mounted) {
      setState(() => _suggestions = list);
    }
  }

  void _executeSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearching = true;
      _suggestions = [];
    });
    final tracks = await _innertubeService.searchTracks(query);
    if (mounted) {
      setState(() {
        _searchResults = tracks;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        // Title
        const Text(
          'Search',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Search Bar with Liquid Glass
        LiquidGlassContainer(
          borderRadius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          tintColor: Colors.white.withOpacity(0.08),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            cursorColor: const Color(0xFFFA2D48),
            onChanged: _onQueryChanged,
            onSubmitted: _executeSearch,
            decoration: InputDecoration(
              icon: const Icon(Icons.search_rounded, color: Colors.white70),
              hintText: 'Songs, artists, podcasts...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: InputBorder.none,
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _suggestions = [];
                          _searchResults = [];
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Suggestion Chips
        if (_suggestions.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return LiquidGlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tintColor: Colors.white.withOpacity(0.06),
                onTap: () {
                  _searchController.text = s;
                  _executeSearch(s);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.north_west_rounded, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      s,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        // Loading
        if (_isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFFFA2D48)),
            ),
          ),

        // Search Results List
        if (!_isSearching && _searchResults.isNotEmpty) ...[
          const Text(
            'Results',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          for (final track in _searchResults)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: track.artUri.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: track.artUri,
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
              title: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                track.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(Icons.play_circle_fill_rounded,
                  color: Color(0xFFFA2D48), size: 30),
              onTap: () {
                widget.audioHandler.playTrack(track, queue: _searchResults);
              },
            ),
        ],
      ],
    );
  }
}
