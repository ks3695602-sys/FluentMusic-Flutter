import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'synced_line.dart';

class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final Map<String, List<SyncedLine>> _lyricsCache = {};

  /// Fetches synced word-by-word karaoke lyrics from Better Lyrics, YoulyPlus, or LRCLIB
  Future<List<SyncedLine>> fetchLyrics({
    required String trackName,
    required String artistName,
    Duration duration = Duration.zero,
  }) async {
    final cleanTrack = _cleanTrackName(trackName);
    final cleanArtist = _cleanArtistName(artistName);
    final cacheKey = '$cleanTrack|$cleanArtist'.toLowerCase();

    if (_lyricsCache.containsKey(cacheKey)) {
      return _lyricsCache[cacheKey]!;
    }

    // 1. Try Better Lyrics & YoulyPlus API
    try {
      final betterLyricsResult = await _fetchFromBetterLyrics(cleanTrack, cleanArtist, duration);
      if (betterLyricsResult.isNotEmpty) {
        _lyricsCache[cacheKey] = betterLyricsResult;
        return betterLyricsResult;
      }
    } catch (e) {
      debugPrint('[LyricsService] BetterLyrics error: $e');
    }

    // 2. Try YoulyPlus / KuGou word-synced source
    try {
      final youlyResult = await _fetchFromYoulyPlus(cleanTrack, cleanArtist);
      if (youlyResult.isNotEmpty) {
        _lyricsCache[cacheKey] = youlyResult;
        return youlyResult;
      }
    } catch (e) {
      debugPrint('[LyricsService] YoulyPlus error: $e');
    }

    // 3. Fallback to LRCLIB (Enhanced word-timing + Synced LRC)
    try {
      final lrclibResult = await _fetchFromLrclib(cleanTrack, cleanArtist, duration);
      if (lrclibResult.isNotEmpty) {
        _lyricsCache[cacheKey] = lrclibResult;
        return lrclibResult;
      }

      final searchResult = await _searchLrclib(cleanTrack, cleanArtist);
      if (searchResult.isNotEmpty) {
        _lyricsCache[cacheKey] = searchResult;
        return searchResult;
      }
    } catch (e) {
      debugPrint('[LyricsService] LRCLIB error: $e');
    }

    return [];
  }

  /// Better Lyrics API: Provides syllable-level word timestamps
  Future<List<SyncedLine>> _fetchFromBetterLyrics(
    String trackName,
    String artistName,
    Duration duration,
  ) async {
    final uri = Uri.parse('https://api.betterlyrics.org/v1/lyrics').replace(
      queryParameters: {
        'title': trackName,
        'artist': artistName,
        if (duration.inSeconds > 0) 'duration': duration.inSeconds.toString(),
      },
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is Map && data['enhancedLrc'] != null) {
        return parseEnhancedLrc(data['enhancedLrc'].toString());
      } else if (data is Map && data['lrc'] != null) {
        return parseEnhancedLrc(data['lrc'].toString());
      }
    }
    return [];
  }

  /// YoulyPlus / Syllable Provider
  Future<List<SyncedLine>> _fetchFromYoulyPlus(
    String trackName,
    String artistName,
  ) async {
    final uri = Uri.parse('https://youly.plus/api/lyrics').replace(
      queryParameters: {
        'q': '$trackName $artistName',
        'format': 'karaoke',
      },
    );

    final res = await http.get(uri).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      if (data is Map && data['lyrics'] != null) {
        return parseEnhancedLrc(data['lyrics'].toString());
      }
    }
    return [];
  }

  /// LRCLIB API: Synced & Plain Lyrics
  Future<List<SyncedLine>> _fetchFromLrclib(
    String trackName,
    String artistName,
    Duration duration,
  ) async {
    final queryParams = {
      'track_name': trackName,
      'artist_name': artistName,
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
        return parseEnhancedLrc(syncedLyrics);
      }
      final plainLyrics = data['plainLyrics'] as String?;
      if (plainLyrics != null && plainLyrics.isNotEmpty) {
        return _parsePlainLyrics(plainLyrics);
      }
    }
    return [];
  }

  Future<List<SyncedLine>> _searchLrclib(String trackName, String artistName) async {
    final uri = Uri.https('lrclib.net', '/api/search', {'q': '$trackName $artistName'});
    final response = await http.get(uri).timeout(const Duration(seconds: 4));

    if (response.statusCode == 200) {
      final list = json.decode(response.body) as List<dynamic>;
      if (list.isNotEmpty) {
        final first = list.first as Map<String, dynamic>;
        final synced = first['syncedLyrics'] as String?;
        if (synced != null && synced.isNotEmpty) {
          return parseEnhancedLrc(synced);
        }
        final plain = first['plainLyrics'] as String?;
        if (plain != null && plain.isNotEmpty) {
          return _parsePlainLyrics(plain);
        }
      }
    }
    return [];
  }

  /// Parses enhanced LRC with word timestamps e.g.:
  /// [00:12.34]<00:12.34>Word1 <00:12.80>Word2 <00:13.20>Word3
  /// Or standard LRC: [00:12.34]Line of text
  List<SyncedLine> parseEnhancedLrc(String lrcContent) {
    final List<SyncedLine> lines = [];
    final lineRegExp = RegExp(r'^\[(\d{2}):(\d{2})\.?(\d{2,3})?\](.*)$');
    final wordRegExp = RegExp(r'<(\d{2}):(\d{2})\.?(\d{2,3})?>([^<]+)');

    final rawLines = lrcContent.split('\n');
    for (int i = 0; i < rawLines.length; i++) {
      final raw = rawLines[i].trim();
      final match = lineRegExp.firstMatch(raw);
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
        final lineTextWithWords = (match.group(4) ?? '').trim();

        if (lineTextWithWords.isNotEmpty) {
          final List<SyncedWord> parsedWords = [];
          final wordMatches = wordRegExp.allMatches(lineTextWithWords).toList();

          if (wordMatches.isNotEmpty) {
            // Enhanced LRC format
            String plainLineText = '';
            for (int w = 0; w < wordMatches.length; w++) {
              final wm = wordMatches[w];
              final wMin = int.tryParse(wm.group(1) ?? '0') ?? 0;
              final wSec = int.tryParse(wm.group(2) ?? '0') ?? 0;
              final wFrac = wm.group(3) ?? '0';
              int wMs = 0;
              if (wFrac.length == 2) {
                wMs = (int.tryParse(wFrac) ?? 0) * 10;
              } else if (wFrac.length >= 3) {
                wMs = int.tryParse(wFrac.substring(0, 3)) ?? 0;
              }
              final wTime = Duration(minutes: wMin, seconds: wSec, milliseconds: wMs);
              final wText = (wm.group(4) ?? '').trim();

              plainLineText += (w > 0 ? ' ' : '') + wText;

              Duration wDuration = const Duration(milliseconds: 350);
              if (w + 1 < wordMatches.length) {
                final nextWm = wordMatches[w + 1];
                final nwMin = int.tryParse(nextWm.group(1) ?? '0') ?? 0;
                final nwSec = int.tryParse(nextWm.group(2) ?? '0') ?? 0;
                final nwFrac = nextWm.group(3) ?? '0';
                int nwMs = (nwFrac.length == 2) ? (int.tryParse(nwFrac) ?? 0) * 10 : int.tryParse(nwFrac.substring(0, 3)) ?? 0;
                final nwTime = Duration(minutes: nwMin, seconds: nwSec, milliseconds: nwMs);
                if (nwTime > wTime) {
                  wDuration = nwTime - wTime;
                }
              }

              parsedWords.add(SyncedWord(
                text: wText,
                time: wTime,
                duration: wDuration,
              ));
            }

            lines.add(SyncedLine(
              time: lineTime,
              text: plainLineText,
              words: parsedWords,
            ));
          } else {
            // Standard LRC: subdivide words evenly for smooth Apple Music karaoke bloom
            final wordsList = lineTextWithWords.split(' ');
            final List<SyncedWord> words = [];
            const defaultWordMs = 320;
            for (int w = 0; w < wordsList.length; w++) {
              words.add(SyncedWord(
                text: wordsList[w],
                time: lineTime + Duration(milliseconds: w * defaultWordMs),
                duration: const Duration(milliseconds: defaultWordMs),
              ));
            }

            lines.add(SyncedLine(
              time: lineTime,
              text: lineTextWithWords,
              words: words,
            ));
          }
        }
      }
    }

    // Calculate line durations
    for (int i = 0; i < lines.length; i++) {
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1];
        if (nextLine.time > lines[i].time) {
          lines[i] = SyncedLine(
            time: lines[i].time,
            text: lines[i].text,
            words: lines[i].words,
            duration: nextLine.time - lines[i].time,
          );
        }
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));
    return lines;
  }

  List<SyncedLine> _parsePlainLyrics(String plainText) {
    final List<SyncedLine> lines = [];
    int counter = 0;
    for (final line in plainText.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        final wordsList = trimmed.split(' ');
        final lineTime = Duration(seconds: counter * 4);
        final words = [
          for (int w = 0; w < wordsList.length; w++)
            SyncedWord(
              text: wordsList[w],
              time: lineTime + Duration(milliseconds: w * 300),
              duration: const Duration(milliseconds: 300),
            )
        ];
        lines.add(SyncedLine(
          time: lineTime,
          text: trimmed,
          words: words,
          duration: const Duration(seconds: 4),
        ));
        counter++;
      }
    }
    return lines;
  }

  String _cleanTrackName(String name) {
    return name
        .replaceAll(RegExp(r'\(.*?\)|\[.*?\]'), '')
        .replaceAll(
          RegExp(
            r'Official Video|Official Audio|Lyric Video|Remastered|feat\..*|ft\..*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  String _cleanArtistName(String name) {
    return name.replaceAll(RegExp(r' - Topic|VEVO', caseSensitive: false), '').trim();
  }
}
