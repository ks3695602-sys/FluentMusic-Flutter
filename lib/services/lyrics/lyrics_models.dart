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
    if (lines == null || lines.isEmpty) return plain ?? '';
    final buffer = StringBuffer();
    for (final line in lines) {
      final m = line.start.inMinutes.toString().padLeft(2, '0');
      final s = (line.start.inSeconds % 60).toString().padLeft(2, '0');
      final ms = ((line.start.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
      if (line.hasWordSync) {
        buffer.write('[$m:$s.$ms]');
        for (final word in line.words) {
          final wm = word.start.inMinutes.toString().padLeft(2, '0');
          final ws = (word.start.inSeconds % 60).toString().padLeft(2, '0');
          final wms = ((word.start.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
          buffer.write('<$wm:$ws.$wms>${word.text}');
        }
        buffer.writeln();
      } else {
        buffer.writeln('[$m:$s.$ms]${line.text}');
      }
    }
    return buffer.toString();
  }
}
