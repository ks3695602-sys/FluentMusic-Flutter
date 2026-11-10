/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     FluentMusic is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'package:html/parser.dart' as html_parser;
import 'package:musify/services/lyrics/lyrics_models.dart';

/// Parses standard and Apple TTML timestamps (e.g. "11.476", "01:14.299", "01:02:03.456")
Duration parseTtmlTime(String? ts) {
  if (ts == null || ts.trim().isEmpty) return Duration.zero;
  final clean = ts.trim();
  if (clean.contains(':')) {
    final parts = clean.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = double.tryParse(parts[1]) ?? 0.0;
      return Duration(milliseconds: (m * 60000 + s * 1000).round());
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = double.tryParse(parts[2]) ?? 0.0;
      return Duration(
        milliseconds: (h * 3600000 + m * 60000 + s * 1000).round(),
      );
    }
  }
  final s = double.tryParse(clean) ?? 0.0;
  return Duration(milliseconds: (s * 1000).round());
}

/// Parses an Apple / BetterLyrics TTML document into time-sorted lines
/// with syllable-level [LyricWord] timestamps.
List<LyricLine> parseTtml(String rawTtml) {
  if (rawTtml.trim().isEmpty) return const [];

  try {
    final document = html_parser.parse(rawTtml);
    final pElements = document.querySelectorAll('p');
    if (pElements.isEmpty) return const [];

    final lines = <LyricLine>[];

    for (final p in pElements) {
      final pBeginStr = p.attributes['begin'];
      if (pBeginStr == null) continue;

      final start = parseTtmlTime(pBeginStr);
      final pEndStr = p.attributes['end'];
      final end = pEndStr != null ? parseTtmlTime(pEndStr) : null;

      final spanElements = p.querySelectorAll('span');
      final words = <LyricWord>[];

      for (final span in spanElements) {
        final text = span.text.trim();
        if (text.isEmpty) continue;

        final spanBegin = span.attributes['begin'];
        final spanEnd = span.attributes['end'];
        final wStart = spanBegin != null ? parseTtmlTime(spanBegin) : start;
        final wEnd = spanEnd != null
            ? parseTtmlTime(spanEnd)
            : (end ?? (wStart + const Duration(milliseconds: 300)));

        words.add(LyricWord(
          text: text,
          start: wStart,
          end: wEnd,
        ));
      }

      final fullText = words.isNotEmpty
          ? words.map((w) => w.text).join(' ')
          : p.text.trim();

      if (fullText.isNotEmpty) {
        lines.add(LyricLine(
          start,
          fullText,
          end: end,
          words: words,
        ));
      }
    }

    lines.sort((a, b) => a.start.compareTo(b.start));
    return lines;
  } catch (_) {
    return const [];
  }
}
