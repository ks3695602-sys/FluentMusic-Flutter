import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../audio/audio_models.dart';

class InnertubeService {
  static final InnertubeService _instance = InnertubeService._internal();
  factory InnertubeService() => _instance;
  InnertubeService._internal();

  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, String> _streamCache = {};

  /// Resolves direct audio stream URL (160kbps Opus or best AAC)
  Future<String?> getAudioStreamUri(String videoId) async {
    if (_streamCache.containsKey(videoId)) {
      return _streamCache[videoId];
    }
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isNotEmpty) {
        final streamUri = audioStreams.last.url.toString();
        _streamCache[videoId] = streamUri;
        return streamUri;
      }
    } catch (e) {
      debugPrint('[InnertubeService] Failed to resolve stream for $videoId: $e');
    }
    return null;
  }

  /// Searches for tracks, playlists, or albums
  Future<List<MediaTrack>> searchTracks(String query) async {
    final List<MediaTrack> results = [];
    try {
      final searchResult = await _yt.search.search(query);
      for (final video in searchResult) {
        results.add(MediaTrack(
          id: video.id.value,
          title: video.title,
          artist: video.author,
          artUri: video.thumbnails.highResUrl.isNotEmpty
              ? video.thumbnails.highResUrl
              : video.thumbnails.standardResUrl,
          duration: video.duration ?? Duration.zero,
        ));
      }
    } catch (e) {
      debugPrint('[InnertubeService] Search error: $e');
    }
    return results;
  }

  /// Auto-complete search suggestions
  Future<List<String>> getSearchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final url = Uri.parse(
          'https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${Uri.encodeComponent(query)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List<dynamic>;
        if (data.length > 1 && data[1] is List) {
          return (data[1] as List).map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint('[InnertubeService] Suggestion error: $e');
    }
    return [];
  }

  /// Tab 1: Personalized & Account Recommendations Feed
  Future<Map<String, List<MediaTrack>>> getPersonalizedHomeFeed() async {
    final Map<String, List<MediaTrack>> feed = {};

    // 1. Quick Picks
    final quickPicks = await searchTracks('trending songs India 2026');
    feed['Quick Picks'] = quickPicks.take(8).toList();

    // 2. Smart Mixes
    final smartMixes = await searchTracks('best pop and chill acoustic hits');
    feed['Smart Mixes'] = smartMixes.take(8).toList();

    // 3. Forgotten Favorites
    final favorites = await searchTracks('retro 90s and 2000s classics hits');
    feed['Forgotten Favorites'] = favorites.take(8).toList();

    // 4. Focus & Chill Radio
    final chillRadio = await searchTracks('lofi hip hop radio chill beats');
    feed['Deep Focus & Chill'] = chillRadio.take(8).toList();

    return feed;
  }

  /// Tab 2: New Releases & Global Discoveries Feed
  Future<Map<String, List<MediaTrack>>> getNewReleasesFeed() async {
    final Map<String, List<MediaTrack>> feed = {};

    // 1. Global Top 50 Charts
    final topCharts = await searchTracks('Global Top 50 hits 2026');
    feed['Global Top 50 Charts'] = topCharts.take(10).toList();

    // 2. Fresh New Releases Radar
    final newDrops = await searchTracks('New music release this week Friday');
    feed['Fresh New Drops'] = newDrops.take(8).toList();

    // 3. Viral Trends
    final viral = await searchTracks('Viral TikTok & Reels top songs');
    feed['Viral Hits Worldwide'] = viral.take(8).toList();

    // 4. Electronic & Dance Beats
    final edm = await searchTracks('EDM festival electronic dance hits 2026');
    feed['Electronic & Dance Beats'] = edm.take(8).toList();

    return feed;
  }

  void dispose() {
    _yt.close();
  }
}
