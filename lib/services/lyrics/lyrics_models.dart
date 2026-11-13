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

/// A song a lyrics lookup is performed for.
class TrackInfo {
  const TrackInfo({
    required this.title,
    required this.artist,
    this.album,
    this.duration,
  });

  final String title;
  final String artist;
  final String? album;
  final Duration? duration;

  TrackInfo copyWith({String? title, String? artist}) => TrackInfo(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album,
    duration: duration,
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

/// Lyrics returned by a provider.
///
/// [plain] is always usable text. [synced] is only set by providers that
/// return timestamps (e.g. LRCLIB) and is sorted by start time.
class Lyrics {
  const Lyrics({required this.source, this.plain, this.synced});

  /// Human readable provider name, e.g. `lrclib.net`.
  final String source;
  final String? plain;
  final List<LyricLine>? synced;

  bool get isSynced => synced != null && synced!.isNotEmpty;

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

  /// Formats the synced lyrics into a standard LRC string compatible with flutter_lyric
  String toLrc() {
    final lines = synced;
    if (lines == null || lines.isEmpty) {
      if (plain == null || plain!.isEmpty) return '';
      return plain!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]'), '');
    }
    final buffer = StringBuffer();
    for (final line in lines) {
      final m = line.start.inMinutes.toString().padLeft(2, '0');
      final s = (line.start.inSeconds % 60).toString().padLeft(2, '0');
      final ms = ((line.start.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
      final cleanText = line.text
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      buffer.writeln('[$m:$s.$ms]$cleanText');
    }
    return buffer.toString();
  }
}
