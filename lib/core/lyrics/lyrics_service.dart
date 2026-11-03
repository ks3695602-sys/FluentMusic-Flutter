import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'synced_line.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Map<String, List<SyncedLine>> _lyricsCache = {};

  Future<List<SyncedLine>> fetchLyrics({
    required String trackName,
    required String artistName,
    Duration duration = Duration.zero,
  }) async {
    final cacheKey = '$trackName|$artistName'.toLowerCase();
    if (_lyricsCache.containsKey(cacheKey)) {
      return _lyricsCache[cacheKey]!;
    }

    // 1. Try LRCLIB API first
    final lrclibResult = await _fetchFromLrclib(trackName, artistName, duration);
    if (lrclibResult.isNotEmpty) {
      _lyricsCache[cacheKey] = lrclibResult;
      return lrclibResult;
    }

    // 2. Fallback to search endpoint
    final searchResult = await _searchLrclib(trackName, artistName);
    if (searchResult.isNotEmpty) {
      _lyricsCache[cacheKey] = searchResult;
      return searchResult;
    }

    return [];
  }

  Future<List<SyncedLine>> _fetchFromLrclib(
    String trackName,
    String artistName,
    Duration duration,
  ) async {
    try {
      final cleanTrack = _cleanTrackName(trackName);
      final cleanArtist = _cleanArtistName(artistName);

      final queryParams = {
        'track_name': cleanTrack,
        'artist_name': cleanArtist,
      };
      if (duration.inSeconds > 0) {
        queryParams['duration'] = duration.inSeconds.toString();
      }

      final uri = Uri.https('lrclib.net', '/api/get', queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final syncedLyrics = data['syncedLyrics'] as String?;
        if (syncedLyrics != null && syncedLyrics.isNotEmpty) {
          return parseLrc(syncedLyrics);
        }
        final plainLyrics = data['plainLyrics'] as String?;
        if (plainLyrics != null && plainLyrics.isNotEmpty) {
          return _parsePlainLyrics(plainLyrics);
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB get error: $e');
    }
    return [];
  }

  Future<List<SyncedLine>> _searchLrclib(String trackName, String artistName) async {
    try {
      final cleanTrack = _cleanTrackName(trackName);
      final uri = Uri.https('lrclib.net', '/api/search', {'q': cleanTrack});
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final list = json.decode(response.body) as List<dynamic>;
        if (list.isNotEmpty) {
          final first = list.first as Map<String, dynamic>;
          final synced = first['syncedLyrics'] as String?;
          if (synced != null && synced.isNotEmpty) {
            return parseLrc(synced);
          }
          final plain = first['plainLyrics'] as String?;
          if (plain != null && plain.isNotEmpty) {
            return _parsePlainLyrics(plain);
          }
        }
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB search error: $e');
    }
    return [];
  }

  List<SyncedLine> parseLrc(String lrcContent) {
    final List<SyncedLine> lines = [];
    final regExp = RegExp(r'\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)');

    for (final rawLine in lrcContent.split('\n')) {
      final match = regExp.firstMatch(rawLine.trim());
      if (match != null) {
        final min = int.tryParse(match.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
        final frac = match.group(3) ?? '0';
        int ms = 0;
        if (frac.length == 2) {
          ms = (int.tryParse(frac) ?? 0) * 10;
        } else if (frac.length >= 3) {
          ms = int.tryParse(frac.substring(0, 3)) ?? 0;
        }

        final lineTime = Duration(minutes: min, seconds: sec, milliseconds: ms);
        final lineText = (match.group(4) ?? '').trim();

        if (lineText.isNotEmpty) {
          lines.add(SyncedLine(
            time: lineTime,
            text: lineText,
            words: _parseWordTimings(lineText, lineTime),
          ));
        }
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  List<SyncedWord> _parseWordTimings(String text, Duration lineTime) {
    // If enhanced LRC with <mm:ss.xx> word timestamps exists, parse it
    final wordMatch = RegExp(r'<(\d{2}):(\d{2})\.?(\d{2,3})?>([^<]+)');
    final matches = wordMatch.allMatches(text);

    if (matches.isNotEmpty) {
      final List<SyncedWord> words = [];
      for (final m in matches) {
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '0') ?? 0;
        final frac = m.group(3) ?? '0';
        int ms = 0;
        if (frac.length == 2) {
          ms = (int.tryParse(frac) ?? 0) * 10;
        } else if (frac.length >= 3) {
          ms = int.tryParse(frac.substring(0, 3)) ?? 0;
        }
        final wordTime = Duration(minutes: min, seconds: sec, milliseconds: ms);
        final wordText = (m.group(4) ?? '').trim();
        if (wordText.isNotEmpty) {
          words.add(SyncedWord(text: wordText, time: wordTime));
        }
      }
      return words;
    }

    // Default: split words evenly across line
    final wordsList = text.split(' ');
    final List<SyncedWord> words = [];
    for (int i = 0; i < wordsList.length; i++) {
      words.add(SyncedWord(
        text: wordsList[i],
        time: lineTime + Duration(milliseconds: i * 250),
      ));
    }
    return words;
  }

  List<SyncedLine> _parsePlainLyrics(String plainText) {
    final List<SyncedLine> lines = [];
    int counter = 0;
    for (final line in plainText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        lines.add(SyncedLine(
          time: Duration(seconds: counter * 4),
          text: trimmed,
        ));
        counter++;
      }
    }
    return lines;
  }

  String _cleanTrackName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(RegExp(r'Official Video|Official Audio|Lyric Video|Remastered|feat\..*|ft\..*', caseSensitive: false), '')
        .trim();
  }

  String _cleanArtistName(String name) {
    return name.replaceAll(RegExp(r' - Topic|VEVO', caseSensitive: false), '').trim();
  }
}
