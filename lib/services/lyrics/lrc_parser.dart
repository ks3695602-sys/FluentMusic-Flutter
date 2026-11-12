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

import 'package:musify/services/lyrics/lyrics_models.dart';

final RegExp _timeTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
final RegExp _offsetTag = RegExp(
  r'^\s*\[offset:\s*([+-]?\d+)\s*\]\s*$',
  caseSensitive: false,
);
final RegExp _wordTag = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');
final RegExp _wordCaptureTag = RegExp(
  r'<(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?>([^<]*)',
);

Duration _parseTimestamp(
  String min,
  String sec,
  String? fraction,
  int offsetMs,
) {
  final minutes = int.parse(min);
  final seconds = int.parse(sec);
  var millis = 0;
  if (fraction != null) {
    millis = int.parse(fraction.padRight(3, '0').substring(0, 3));
  }
  final total =
      Duration(minutes: minutes, seconds: seconds, milliseconds: millis) -
      Duration(milliseconds: offsetMs);
  return total.isNegative ? Duration.zero : total;
}

/// Parses LRC text into time-sorted lines with word-level timestamps when available.
///
/// Supports `[mm:ss]`, `[mm:ss.xx]`, `[mm:ss.xxx]`, multiple timestamps on one
/// line, the `[offset:ms]` header, and enhanced `<mm:ss.xx>word` tags.
List<LyricLine> parseLrc(String input) {
  final lines = <LyricLine>[];
  var offsetMs = 0;

  for (final raw in input.split(RegExp(r'\r?\n'))) {
    final offsetMatch = _offsetTag.firstMatch(raw);
    if (offsetMatch != null) {
      offsetMs = int.tryParse(offsetMatch.group(1)!) ?? 0;
      continue;
    }

    final matches = _timeTag.allMatches(raw).toList();
    if (matches.isEmpty) continue;

    final rawContent = raw.substring(matches.last.end);
    final text = rawContent
        .replaceAll(_wordTag, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Parse enhanced word-by-word timestamps if present
    final wordMatches = _wordCaptureTag.allMatches(rawContent).toList();
    final parsedWords = <LyricWord>[];
    if (wordMatches.isNotEmpty) {
      for (var i = 0; i < wordMatches.length; i++) {
        final wm = wordMatches[i];
        final wStart = _parseTimestamp(
          wm.group(1)!,
          wm.group(2)!,
          wm.group(3),
          offsetMs,
        );
        final wText = wm.group(4) ?? '';

        Duration wEnd;
        if (i + 1 < wordMatches.length) {
          final nextWm = wordMatches[i + 1];
          wEnd = _parseTimestamp(
            nextWm.group(1)!,
            nextWm.group(2)!,
            nextWm.group(3),
            offsetMs,
          );
        } else {
          // Default last word duration of 600ms
          wEnd = wStart + const Duration(milliseconds: 600);
        }

        if (wText.isNotEmpty) {
          parsedWords.add(LyricWord(text: wText, start: wStart, end: wEnd));
        }
      }
    }

    for (final m in matches) {
      final total = _parseTimestamp(
        m.group(1)!,
        m.group(2)!,
        m.group(3),
        offsetMs,
      );
      final lineEnd = parsedWords.isNotEmpty ? parsedWords.last.end : null;
      lines.add(
        LyricLine(
          total,
          text,
          end: lineEnd,
          words: parsedWords,
        ),
      );
    }
  }

  // Stable sort so equal timestamps keep their file order.
  final indexed = lines.asMap().entries.toList()
    ..sort((a, b) {
      final c = a.value.start.compareTo(b.value.start);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  final sortedLines = indexed.map((e) => e.value).toList();
  for (var i = 0; i < sortedLines.length; i++) {
    if (sortedLines[i].end == null && i + 1 < sortedLines.length) {
      final nextStart = sortedLines[i + 1].start;
      if (nextStart > sortedLines[i].start) {
        sortedLines[i] = LyricLine(
          sortedLines[i].start,
          sortedLines[i].text,
          end: nextStart,
          words: sortedLines[i].words,
        );
      }
    }
  }
  return sortedLines;
}
