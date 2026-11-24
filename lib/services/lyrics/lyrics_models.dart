/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:characters/characters.dart';

/// A song a lyrics lookup is performed for.
class TrackInfo {
  const TrackInfo({
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.videoId,
  });

  final String title;
  final String artist;
  final String? album;
  final Duration? duration;

  /// YouTube video id, when the caller has one.
  ///
  /// Providers that key on the exact upload (Unison) use it to skip a fuzzy
  /// title/artist search, so the lookup cannot drift to a live or remix cut.
  final String? videoId;

  TrackInfo copyWith({String? title, String? artist, String? videoId}) =>
      TrackInfo(
        title: title ?? this.title,
        artist: artist ?? this.artist,
        album: album,
        duration: duration,
        videoId: videoId ?? this.videoId,
      );
}

/// One timed word/syllable of an enhanced synchronized (LRC) lyrics file.
class LyricWord {
  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
  });

  final String text;
  final Duration start;
  final Duration end;

  @override
  String toString() => '<$start->$end> $text';
}

/// One timed line of a synchronized (LRC) lyrics file with word-sync support.
class LyricLine {
  const LyricLine(
    this.start,
    this.text, {
    this.end,
    this.words = const [],
  });

  final Duration start;
  final Duration? end;
  final String text;
  final List<LyricWord> words;

  bool get hasWordSync => words.isNotEmpty;

  /// Generates character-weighted syllable durations when provider timestamps are line-only (YouLyPlus model).
  List<LyricWord> get interpolatedWords {
    if (words.isNotEmpty) return words;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final splitWords = trimmed.split(RegExp(r'\s+'));
    if (splitWords.isEmpty) return const [];

    final lineDuration = (end != null && end! > start)
        ? end! - start
        : const Duration(seconds: 4);

    final totalChars = splitWords.fold<int>(0, (sum, w) => sum + w.length);
    if (totalChars <= 0) return const [];

    var currentStart = start;
    final result = <LyricWord>[];
    for (var i = 0; i < splitWords.length; i++) {
      final w = splitWords[i];
      final wordMillis =
          (lineDuration.inMilliseconds * (w.length / totalChars)).round();
      final wordEnd = (i == splitWords.length - 1)
          ? (end ?? (currentStart + Duration(milliseconds: wordMillis)))
          : (currentStart + Duration(milliseconds: wordMillis));

      result.add(LyricWord(text: w, start: currentStart, end: wordEnd));
      currentStart = wordEnd;
    }
    return result;
  }

  /// Returns the index of the word sung at [position], or -1 if before line start.
  int wordIndexAt(Duration position) {
    if (words.isEmpty) return -1;
    for (var i = 0; i < words.length; i++) {
      if (position >= words[i].start && position < words[i].end) {
        return i;
      }
    }
    if (position >= words.last.end) {
      return words.length - 1;
    }
    return -1;
  }

  @override
  String toString() => '[$start] $text';
}

/// Inserts zero-width break opportunities without changing visible lyrics.
/// Counts grapheme clusters so emoji, combining marks and RTL text stay intact.
const int _defaultMaxUnbrokenLyricGraphemes = 5;
const String _lyricZeroWidthBreak = '\u200B';
final RegExp _lyricTokenPattern = RegExp(r'\S+');
final RegExp _lyricMarkupPattern = RegExp(r'<[^>]+>');
final RegExp _lyricTimestampPattern =
    RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]');

String _cleanLyricForDisplay(String text, {bool collapseWhitespace = false}) {
  var clean = text
      .replaceAll(_lyricMarkupPattern, '')
      .replaceAll(_lyricTimestampPattern, '');
  if (collapseWhitespace) clean = clean.replaceAll(RegExp(r'\s+'), ' ');
  return clean.trim();
}

List<int> _longTokenBreakOffsets(String text, int maxGraphemes) {
  final offsets = <int>[];
  for (final match in _lyricTokenPattern.allMatches(text)) {
    final tokenClusters = match.group(0)!.characters.toList();
    var tokenGraphemes = 0;
    var utf16Offset = match.start;
    for (var i = 0; i < tokenClusters.length; i++) {
      final cluster = tokenClusters[i];
      utf16Offset += cluster.length;
      if (cluster == _lyricZeroWidthBreak) {
        tokenGraphemes = 0;
        continue;
      }
      tokenGraphemes++;
      if (tokenGraphemes == maxGraphemes &&
          i + 1 < tokenClusters.length &&
          tokenClusters[i + 1] != _lyricZeroWidthBreak) {
        offsets.add(utf16Offset);
        tokenGraphemes = 0;
      }
    }
  }
  return offsets;
}

String wrapLongLyricTokens(
  String text, {
  int maxGraphemes = _defaultMaxUnbrokenLyricGraphemes,
}) {
  if (maxGraphemes < 1) {
    throw ArgumentError.value(
      maxGraphemes,
      'maxGraphemes',
      'must be positive',
    );
  }
  final offsets = _longTokenBreakOffsets(text, maxGraphemes);
  if (offsets.isEmpty) return text;

  final buffer = StringBuffer();
  var previousOffset = 0;
  for (final offset in offsets) {
    buffer
      ..write(text.substring(previousOffset, offset))
      ..write(_lyricZeroWidthBreak);
    previousOffset = offset;
  }
  buffer.write(text.substring(previousOffset));
  return buffer.toString();
}

/// Lyrics returned by a provider.
///
/// [plain] is always usable text. [synced] is only set by providers that
/// return timestamps (e.g. LRCLIB) and is sorted by start time.
class Lyrics {
  const Lyrics({
    required this.source,
    this.plain,
    this.synced,
    this.credit,
  });

  /// Human readable provider name, e.g. `lrclib.net`.
  final String source;
  final String? plain;
  final List<LyricLine>? synced;

  /// Full attribution line the provider requires, when its licence asks for
  /// more than a plain source name (Unison: "Lyrics from Unison · submitted
  /// by …"). Null for providers that only need the source named.
  final String? credit;

  /// Text to show wherever lyrics are credited.
  String get attribution => credit ?? 'Lyrics by $source';

  bool get isSynced => synced != null && synced!.isNotEmpty;
  bool get hasWordSync => synced?.any((l) => l.hasWordSync) ?? false;

  /// Plain text, derived from [synced] when the provider sent no plain text.
  String get text {
    final p = plain;
    if (p != null && p.trim().isNotEmpty) return p;
    return (synced ?? const <LyricLine>[]).map((l) => l.text).join('\n');
  }

  bool get isEmpty => text.trim().isEmpty;

  /// Index of the line that should be highlighted at [position], or -1 when
  /// the song has not reached the first line yet.
  int lineIndexAt(Duration position) {
    final lines = synced;
    if (lines == null || lines.isEmpty) return -1;
    var lo = 0;
    var hi = lines.length - 1;
    var result = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (lines[mid].start <= position) {
        result = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return result;
  }

  /// Formats lyrics for flutter_lyric and adds zero-width breaks to long tokens.
  String toLrc({
    int maxUnbrokenGraphemes = _defaultMaxUnbrokenLyricGraphemes,
  }) {
    if (maxUnbrokenGraphemes < 1) {
      throw ArgumentError.value(
        maxUnbrokenGraphemes,
        'maxUnbrokenGraphemes',
        'must be positive',
      );
    }
    final lines = synced;
    if (lines == null || lines.isEmpty) {
      if (plain == null || plain!.isEmpty) return '';
      return wrapLongLyricTokens(
        _cleanLyricForDisplay(plain!),
        maxGraphemes: maxUnbrokenGraphemes,
      );
    }
    final buffer = StringBuffer();
    for (final line in lines) {
      final m = line.start.inMinutes.toString().padLeft(2, '0');
      final s = (line.start.inSeconds % 60).toString().padLeft(2, '0');
      final ms = ((line.start.inMilliseconds % 1000) ~/ 10)
          .toString()
          .padLeft(2, '0');
      final cleanText = wrapLongLyricTokens(
        _cleanLyricForDisplay(line.text, collapseWhitespace: true),
        maxGraphemes: maxUnbrokenGraphemes,
      );
      buffer.writeln('[$m:$s.$ms]$cleanText');
    }
    return buffer.toString();
  }

  /// Formats lyrics for flutter_lyric's QRC parser with optional word timing.
  /// Long tokens receive zero-width break opportunities for safe wrapping.
  String toQrc({
    int maxUnbrokenGraphemes = _defaultMaxUnbrokenLyricGraphemes,
  }) {
    if (maxUnbrokenGraphemes < 1) {
      throw ArgumentError.value(
        maxUnbrokenGraphemes,
        'maxUnbrokenGraphemes',
        'must be positive',
      );
    }
    final lines = synced;
    if (lines == null || lines.isEmpty) {
      return toLrc(maxUnbrokenGraphemes: maxUnbrokenGraphemes);
    }
    if (!hasWordSync) {
      return toLrc(maxUnbrokenGraphemes: maxUnbrokenGraphemes);
    }

    final buffer = StringBuffer();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineStartMs = line.start.inMilliseconds;
      final lineEndMs = (line.end != null && line.end! > line.start)
          ? line.end!.inMilliseconds
          : (i + 1 < lines.length
              ? lines[i + 1].start.inMilliseconds
              : lineStartMs + 4000);
      final lineDurMs = (lineEndMs - lineStartMs).clamp(200, 30000);

      if (line.hasWordSync) {
        buffer.write('[$lineStartMs,$lineDurMs]');
        for (var j = 0; j < line.words.length; j++) {
          final word = line.words[j];
          final cleanWord = wrapLongLyricTokens(
            _cleanLyricForDisplay(word.text),
            maxGraphemes: maxUnbrokenGraphemes,
          );
          if (cleanWord.isEmpty) continue;
          final wStart = word.start.inMilliseconds;
          final wDur = (word.end.inMilliseconds - wStart).clamp(30, 10000);
          final trailingSpace = (j < line.words.length - 1) ? ' ' : '';
          buffer.write('$cleanWord$trailingSpace($wStart,$wDur)');
        }
        buffer.writeln();
      } else {
        final cleanText = wrapLongLyricTokens(
          _cleanLyricForDisplay(line.text, collapseWhitespace: true),
          maxGraphemes: maxUnbrokenGraphemes,
        );
        buffer.writeln(
          '[$lineStartMs,$lineDurMs]$cleanText($lineStartMs,$lineDurMs)',
        );
      }
    }
    return buffer.toString();
  }
}
