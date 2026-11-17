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

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/utilities/ytmusic_metadata.dart';

void main() {
  group('isJunkArtist', () {
    test('rejects item types and row decorations', () {
      expect(isJunkArtist('Song'), isTrue);
      expect(isJunkArtist('single'), isTrue);
      expect(isJunkArtist('Album'), isTrue);
      expect(isJunkArtist('Playlist'), isTrue);
      expect(isJunkArtist('3:42'), isTrue);
      expect(isJunkArtist('1:02:03'), isTrue);
      expect(isJunkArtist('2024'), isTrue);
      expect(isJunkArtist('1.2M views'), isTrue);
      expect(isJunkArtist('12,345 plays'), isTrue);
      expect(isJunkArtist('•'), isTrue);
      expect(isJunkArtist('   '), isTrue);
    });

    test('keeps real artist names', () {
      expect(isJunkArtist('The Weeknd'), isFalse);
      expect(isJunkArtist('The Views'), isFalse);
      expect(isJunkArtist('Simon & Garfunkel'), isFalse);
      expect(isJunkArtist('T-Pain'), isFalse);
      expect(isJunkArtist('Adele'), isFalse);
    });
  });

  group('pickArtistFromRuns', () {
    test('skips the leading item type', () {
      expect(
        pickArtistFromRuns(['Song', 'The Weeknd', 'After Hours', '3:22']),
        'The Weeknd',
      );
      expect(pickArtistFromRuns(['Single', 'Adele']), 'Adele');
    });

    test('handles tokens packed into one run', () {
      expect(
        pickArtistFromRuns(['Song • The Weeknd • After Hours']),
        'The Weeknd',
      );
    });

    test('skips years, durations and view counts before the artist', () {
      expect(pickArtistFromRuns(['2024', 'Adele']), 'Adele');
      expect(pickArtistFromRuns(['3:42', 'Adele']), 'Adele');
      expect(pickArtistFromRuns(['1.2M views', 'Adele']), 'Adele');
    });

    test('returns null when nothing looks like an artist', () {
      expect(pickArtistFromRuns(['Song', 'Single', '3:42']), isNull);
      expect(pickArtistFromRuns(const []), isNull);
    });
  });

  group('pickArtistFromSubtitles', () {
    test('prefers a linked artist channel over the type label', () {
      final subtitle = {
        'runs': [
          {'text': 'Song'},
          {
            'text': 'After Hours',
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'MPRE123'},
            },
          },
          {
            'text': 'The Weeknd',
            'navigationEndpoint': {
              'browseEndpoint': {'browseId': 'UC1234567890'},
            },
          },
        ],
      };

      expect(pickArtistFromSubtitles([subtitle]), 'The Weeknd');
    });

    test('falls back to the first plausible run without links', () {
      final subtitle = {
        'runs': [
          {'text': 'Single'},
          {'text': 'Adele'},
          {'text': '25'},
        ],
      };

      expect(pickArtistFromSubtitles([subtitle]), 'Adele');
    });

    test('splits simpleText rows', () {
      expect(
        pickArtistFromSubtitles([
          {'simpleText': 'Single • Adele • 25'},
        ]),
        'Adele',
      );
    });

    test('returns null for type-only subtitles', () {
      expect(
        pickArtistFromSubtitles([
          {
            'runs': [
              {'text': 'Song'},
              {'text': '3:42'},
            ],
          },
        ]),
        isNull,
      );
    });
  });
}
