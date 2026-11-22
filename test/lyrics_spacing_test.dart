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

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/mornye_player/utils/lyrics_parser.dart';
import 'package:musify/mornye_player/utils/lyrics_spacing.dart';

LyricWord _word(String text, int atMs) => LyricWord(
  time: Duration(milliseconds: atMs),
  text: text,
);

void main() {
  group('reattachWordSpacing', () {
    test('keeps the spaces between trimmed TTML tokens', () {
      const line = 'I was on the outside, always looking in';
      final words = [
        _word('I', 0),
        _word('was', 200),
        _word('on', 400),
        _word('the', 600),
        _word('outside,', 800),
        _word('always', 1200),
        _word('looking', 1400),
        _word('in', 1600),
      ];

      final segments = reattachWordSpacing(line, words);

      expect(segments.join(), line);
      expect(segments.first, 'I ');
      expect(segments[4], 'outside, ');
      expect(segments.last, 'in');
    });

    test('does not invent spaces in CJK lines', () {
      const line = '你好世界';
      final words = [_word('你好', 0), _word('世界', 900)];

      final segments = reattachWordSpacing(line, words);

      expect(segments, ['你好', '世界']);
      expect(segments.join(), line);
    });

    test('handles repeated words without drifting', () {
      const line = 'la la la';
      final words = [_word('la', 0), _word('la', 300), _word('la', 600)];

      expect(reattachWordSpacing(line, words), ['la ', 'la ', 'la']);
    });

    test('falls back to single spaces when a token was rewritten', () {
      const line = 'Hello world';
      final words = [_word('Hello', 0), _word('there', 500)];

      final segments = reattachWordSpacing(line, words);

      expect(segments, ['Hello ', 'there']);
      expect(segments.join(), isNot('Hellothere'));
    });
  });
}
