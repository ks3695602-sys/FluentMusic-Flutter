/*
 *     Copyright (C) 2026 Valeri Gokadze
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
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:musify/mornye_player/utils/lyrics_parser.dart';

/// Reattaches the whitespace between timed words from the line itself.
///
/// TTML and several word-synced providers hand us trimmed word tokens
/// (`I`, `was`, `on`...). Concatenating those tokens dropped every space and
/// painted the active line as `Iwasontheoutside`. The full line is the source
/// of truth for the gaps, so a segment runs from its token up to the start of
/// the next one. That keeps spaces, punctuation and CJK text exactly as the
/// provider wrote them.
///
/// When a provider rewrote a token so it cannot be located in the line, the
/// fallback inserts one space between tokens; a duplicated or rearranged line
/// is still readable, which is better than gluing every word together.
List<String> reattachWordSpacing(String lineText, List<LyricWord> words) {
  if (words.isEmpty) return const [];

  final segments = <String>[];
  var cursor = 0;
  for (var index = 0; index < words.length; index++) {
    final token = words[index].text;
    if (token.isEmpty) {
      segments.add('');
      continue;
    }

    final at = lineText.indexOf(token, cursor);
    if (at < 0) return _withJoinedSpaces(words);

    final next = index + 1 < words.length
        ? lineText.indexOf(words[index + 1].text, at + token.length)
        : lineText.length;
    if (next < 0) return _withJoinedSpaces(words);

    segments.add(lineText.substring(at, next));
    cursor = next;
  }
  return segments;
}

List<String> _withJoinedSpaces(List<LyricWord> words) => [
  for (var index = 0; index < words.length; index++)
    index + 1 == words.length ? words[index].text : '${words[index].text} ',
];
