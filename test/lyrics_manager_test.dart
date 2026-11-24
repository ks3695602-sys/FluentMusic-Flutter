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

import 'dart:convert';

import 'package:flutter_lyric/flutter_lyric.dart' show LyricParser;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:musify/services/lyrics/binimum_provider.dart';
import 'package:musify/services/lyrics/lrc_parser.dart';
import 'package:musify/services/lyrics/lyrics_query.dart';
import 'package:musify/services/lyrics_manager.dart';

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _ttml(String body, [int status = 200]) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/ttml+xml; charset=utf-8'},
);

const _binimumTtml =
    '<tt><body><div>'
    '<p begin="0:09.845" end="0:12.105">'
    '<span begin="0:09.845" end="0:10.056">I</span> '
    '<span begin="0:10.056" end="0:10.383">was</span> '
    '<span begin="0:10.383" end="0:12.105">on</span>'
    '</p>'
    '<p begin="0:12.234" end="0:14.243">'
    '<span begin="0:12.234" end="0:12.901">the</span> '
    '<span begin="0:12.901" end="0:14.243">outside</span>'
    '</p>'
    '</div></body></tt>';

void main() {
  group('parseLrc', () {
    test('parses timestamps, fractions and sorts lines', () {
      final lines = parseLrc('[ar:Someone]\n[00:12.5]second\n[00:01.00]first');
      expect(lines.length, 2);
      expect(lines[0].text, 'first');
      expect(lines[0].start, const Duration(seconds: 1));
      expect(lines[1].start, const Duration(seconds: 12, milliseconds: 500));
    });

    test('supports multiple timestamps, word tags and offset', () {
      final lines = parseLrc(
        '[offset:500]\n[00:10.00][00:20.00]<00:10.00>hel<00:10.50>lo',
      );
      expect(lines.length, 2);
      expect(lines[0].text, 'hello');
      expect(lines[0].start, const Duration(seconds: 9, milliseconds: 500));
      expect(lines[1].start, const Duration(seconds: 19, milliseconds: 500));
    });

    test('ignores plain text and clamps negative times', () {
      expect(parseLrc('just text\nno tags'), isEmpty);
      expect(parseLrc('[offset:5000]\n[00:01.00]x').first.start, Duration.zero);
    });
  });

  group('Lyrics', () {
    test('lineIndexAt finds the active line', () {
      final lyrics = Lyrics(
        source: 't',
        synced: parseLrc('[00:05.00]a\n[00:10.00]b\n[00:15.00]c'),
      );
      expect(lyrics.lineIndexAt(const Duration(seconds: 1)), -1);
      expect(lyrics.lineIndexAt(const Duration(seconds: 5)), 0);
      expect(lyrics.lineIndexAt(const Duration(seconds: 12)), 1);
      expect(lyrics.lineIndexAt(const Duration(minutes: 5)), 2);
    });

    test('text falls back to synced lines', () {
      final lyrics = Lyrics(source: 't', synced: parseLrc('[00:01.00]a'));
      expect(lyrics.text, 'a');
      expect(lyrics.isSynced, isTrue);
    });

    test('wraps long tokens without splitting grapheme clusters', () {
      expect(wrapLongLyricTokens('ooooo'), 'ooooo');
      expect(wrapLongLyricTokens('oooooo'), 'ooooo\u200Bo');
      expect(
        wrapLongLyricTokens('oooooooooooooo'),
        'ooooo\u200Booooo\u200Boooo',
      );
      expect(
        wrapLongLyricTokens('🧑‍🎤🧑‍🎤🧑‍🎤', maxGraphemes: 2),
        '🧑‍🎤🧑‍🎤\u200B🧑‍🎤',
      );
      expect(wrapLongLyricTokens('two words'), 'two words');
      const arabic = 'مرحبابالعالم';
      final wrappedArabic = wrapLongLyricTokens(arabic, maxGraphemes: 4);
      expect(wrappedArabic.replaceAll('\u200B', ''), arabic);
      expect(wrappedArabic, contains('\u200B'));
      expect(
        () => wrapLongLyricTokens('text', maxGraphemes: 0),
        throwsArgumentError,
      );
    });

    test('adds break opportunities in LRC and QRC output', () {
      final lyrics = Lyrics(
        source: 't',
        synced: [
          const LyricLine(Duration(seconds: 1), 'oooooooooooooooo'),
          LyricLine(
            Duration(seconds: 5),
            'oooooooooooooooo',
            words: [
              LyricWord(
                text: 'oooooooooooooooo',
                start: Duration(seconds: 5),
                end: Duration(seconds: 8),
              ),
            ],
          ),
        ],
      );
      final lrc = lyrics.toLrc();
      expect(lrc.split('\n').first, contains('\u200B'));
      expect(
        parseLrc(lrc).first.text.replaceAll('\u200B', ''),
        'oooooooooooooooo',
      );
      final qrc = lyrics.toQrc();
      expect(qrc, contains('\u200B'));
      final roundTripQrc = LyricParser.autoDetect(qrc);
      expect(
        roundTripQrc.lines.last.text.replaceAll('\u200B', ''),
        'oooooooooooooooo',
      );
    });
  });

  group('lyrics_query', () {
    test('cleanTitle removes YouTube decorations', () {
      expect(cleanTitle('Blinding Lights (Official Video)'), 'Blinding Lights');
      expect(cleanTitle('Song [Lyrics] feat. Someone'), 'Song');
      expect(cleanTitle('Song - Remastered 2011'), 'Song');
      expect(cleanTitle('Song Lyrics'), 'Song');
      expect(cleanTitle('Song | Official Audio'), 'Song');
      expect(cleanTitle('Song (Acoustic)'), 'Song (Acoustic)');
      expect(cleanTitle('Lyrics'), 'Lyrics');
    });

    test('cleanArtist keeps the primary artist', () {
      expect(cleanArtist('The Weeknd - Topic'), 'The Weeknd');
      expect(cleanArtist('Adele, Someone'), 'Adele');
      expect(cleanArtist('AdeleVEVO'), 'Adele');
      expect(cleanArtist('Simon & Garfunkel'), 'Simon & Garfunkel');
    });

    test('cleanArtist rejects account library item types', () {
      expect(cleanArtist('Song'), '');
      expect(cleanArtist('Single'), '');
      expect(cleanArtist('Album'), '');
      expect(cleanArtist('Single, The Weeknd'), 'The Weeknd');
      expect(cleanArtist('Song, Single, Adele'), 'Adele');
    });

    test('slugs fold accents and reject non-Latin text', () {
      expect(lyricsSlug('Beyoncé  Knowles'), 'beyonce-knowles');
      expect(lyricsSlug("Don't Stop!"), 'dont-stop');
      expect(lyricsSlug('فيروز'), '');
      expect(lyricsManiaSlug(' Hello World '), 'hello_world');
    });

    test('buildSearchVariants handles "Artist - Song" and swapped titles', () {
      final variants = buildSearchVariants(
        const TrackInfo(title: 'Queen - Bohemian Rhapsody', artist: 'Queen'),
      );
      expect(variants.first.artist, 'Queen');
      expect(variants.first.title, 'Bohemian Rhapsody');
      expect(
        variants.any(
          (v) => v.artist == 'Bohemian Rhapsody' && v.title == 'Queen',
        ),
        isTrue,
      );
      expect(variants.length, 3); // duplicates are removed
      expect(
        buildSearchVariants(const TrackInfo(title: 'Song', artist: 'Artist'))
            .length,
        1,
      );
    });

    test('recovers the artist from a dashed title when the field is junk', () {
      final variants = buildSearchVariants(
        const TrackInfo(title: 'The Weeknd - Blinding Lights', artist: 'Song'),
      );
      expect(variants, isNotEmpty);
      expect(variants.first.artist, 'The Weeknd');
      expect(variants.first.title, 'Blinding Lights');
    });

    test('keeps the raw title as a rescue variant', () {
      final variants = buildSearchVariants(
        const TrackInfo(title: 'Song | Official Audio', artist: 'Artist'),
      );
      expect(variants.first.title, 'Song');
      expect(variants.any((v) => v.title == 'Song | Official Audio'), isTrue);
      expect(
        buildSearchVariants(const TrackInfo(title: 'Song', artist: 'Artist'))
            .length,
        1,
      );
    });
  });

  group('selectBestLrclibMatch', () {
    const track = TrackInfo(
      title: 'Song',
      artist: 'Artist',
      duration: Duration(seconds: 200),
    );

    test('prefers matching duration over a different version', () {
      final best = selectBestLrclibMatch([
        {
          'trackName': 'Song',
          'artistName': 'Artist',
          'duration': 260,
          'plainLyrics': 'live',
        },
        {
          'trackName': 'Song',
          'artistName': 'Artist',
          'duration': 201,
          'plainLyrics': 'studio',
        },
      ], track);
      expect(best!['plainLyrics'], 'studio');
    });

    test('rejects unrelated and instrumental results', () {
      expect(
        selectBestLrclibMatch([
          {
            'trackName': 'Other',
            'artistName': 'Artist',
            'duration': 200,
            'plainLyrics': 'x',
          },
          {
            'trackName': 'Song',
            'artistName': 'Artist',
            'instrumental': true,
            'plainLyrics': 'x',
          },
        ], track),
        isNull,
      );
    });
  });

  group('fetchFromBinimum', () {
    test('picks a word-timed result and parses its TTML', () async {
      final requestedUris = <Uri>[];
      final client = MockClient((request) async {
        requestedUris.add(request.url);
        if (request.url.host == 'lyrics-api.binimum.org') {
          expect(request.url.queryParameters['track'], 'Shape of You');
          expect(request.url.queryParameters['artist'], 'Ed Sheeran');
          expect(request.url.queryParameters['duration'], '233');
          return http.Response(
            '',
            307,
            headers: {
              'location': 'https://lrc.red/api/v1?track=Shape%20of%20You&artist=Ed%20Sheeran&duration=233',
            },
          );
        }
        if (request.url.host == 'lrc.red' && request.url.path == '/api/v1') {
          return _json({
            'results': [
              {
                'lyricsUrl': 'https://lrc.red/s/word-wrong-duration.ttml',
                'timing_type': 'word',
                'duration': 250.0,
              },
              {
                'lyricsUrl': 'https://lrc.red/s/plain.ttml',
                'timing_type': 'line',
                'duration': 233.0,
              },
              {
                'lyricsUrl': 'https://lrc.red/s/word.ttml',
                'timing_type': 'word',
                'duration': 234.0,
              },
            ],
          });
        }
        expect(request.url.host, 'lrc.red');
        if (request.url.path == '/s/word-wrong-duration.ttml') {
          fail('Did not choose the closest-duration word-timed match');
        }
        return _ttml(_binimumTtml);
      });

      final lyrics = await fetchFromBinimum(
        const TrackInfo(
          title: 'Shape of You',
          artist: 'Ed Sheeran',
          duration: Duration(seconds: 233),
        ),
        client: client,
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.source, 'Binimum Lyrics');
      expect(lyrics.isSynced, isTrue);
      expect(
        lyrics.synced!.first.start,
        const Duration(seconds: 9, milliseconds: 845),
      );
      expect(
        lyrics.synced!.first.end,
        const Duration(seconds: 12, milliseconds: 105),
      );
      expect(lyrics.synced!.length, 2);
      expect(lyrics.synced!.first.words.length, 3);
      expect(lyrics.synced!.first.words.first.text, 'I');
      // Text nodes between spans are preserved for the renderer's spacing fix.
      expect(lyrics.synced!.first.text, 'I was on');
      // The API's redirect and returned TTML URL are followed safely.
      expect(
        requestedUris.any(
          (uri) => uri.host == 'lrc.red' && uri.path == '/api/v1',
        ),
        isTrue,
      );
      expect(requestedUris.any((uri) => uri.path == '/s/word.ttml'), isTrue);
      expect(
        requestedUris.any((uri) => uri.path == '/s/word-wrong-duration.ttml'),
        isFalse,
      );
    });

    test('returns null when the API has no results', () async {
      final client = MockClient((request) async => _json({'results': []}));
      expect(
        await fetchFromBinimum(
          const TrackInfo(title: 'Unknown', artist: 'Nobody'),
          client: client,
        ),
        isNull,
      );
    });

    test('returns null on a non-200 search response', () async {
      final client = MockClient((request) async => _json({'results': []}, 503));
      expect(
        await fetchFromBinimum(
          const TrackInfo(title: 'Song', artist: 'Artist'),
          client: client,
        ),
        isNull,
      );
    });

    test('returns null when the TTML document is not TTML', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'lyrics-api.binimum.org') {
          return _json({
            'results': [
              {'lyricsUrl': 'https://ttml.example/word', 'timing_type': 'word'},
            ],
          });
        }
        return _ttml('<html><body>nope</body></html>');
      });
      expect(
        await fetchFromBinimum(
          const TrackInfo(title: 'Song', artist: 'Artist'),
          client: client,
        ),
        isNull,
      );
    });

    test('requires a title and an artist', () async {
      final client = MockClient((request) async => _json({'results': []}));
      expect(
        await fetchFromBinimum(
          const TrackInfo(title: '', artist: 'Artist'),
          client: client,
        ),
        isNull,
      );
    });
  });

  group('LyricsManager', () {
    setUp(LyricsManager.clearCache);

    test('returns synced LRCLIB lyrics when available', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'lrclib.net');
        return _json([
          {
            'trackName': 'Song',
            'artistName': 'Artist',
            'duration': 200,
            'plainLyrics': 'plain',
            'syncedLyrics': '[00:01.00]hello\n[00:05.00]world',
          },
        ]);
      });
      final result =
          await LyricsManager(
            client: client,
            providers: const [LyricsProvider.lrclib],
          ).fetchLyricsResult(
            const TrackInfo(
              title: 'Song (Official Video)',
              artist: 'Artist - Topic',
              duration: Duration(seconds: 200),
            ),
          );
      expect(result!.isSynced, isTrue);
      expect(result.source, 'lrclib.net');
      expect(result.synced!.length, 2);
    });

    test(
      'uses Unison for the exact video id and keeps submitter credit',
      () async {
        final client = MockClient((request) async {
          expect(request.url.host, 'unison.betterlyrics.org');
          expect(request.url.queryParameters['v'], 'abc123');
          return _json({
            'success': true,
            'data': {
              'format': 'lrc',
              'syncType': 'linesync',
              'lyrics': '[00:01.00]hello\n[00:05.00]world',
              'submitter': {'keyId': 'k', 'displayName': 'boidu'},
            },
          });
        });

        final result =
            await LyricsManager(
              client: client,
              providers: const [LyricsProvider.unison],
            ).fetchLyricsResult(
              const TrackInfo(
                title: 'Song',
                artist: 'Artist',
                videoId: 'abc123',
              ),
            );

        expect(result, isNotNull);
        expect(result!.source, 'Unison');
        expect(result.isSynced, isTrue);
        expect(result.synced!.length, 2);
        expect(result.attribution, 'Lyrics from Unison · submitted by boidu');
      },
    );

    test('keeps the Unison credit without a submitter name', () async {
      final client = MockClient((request) async {
        return _json({
          'success': true,
          'data': {
            'format': 'plain',
            'syncType': 'plain',
            'lyrics': 'just words',
          },
        });
      });

      final result =
          await LyricsManager(
            client: client,
            providers: const [LyricsProvider.unison],
          ).fetchLyricsResult(
            const TrackInfo(title: 'Song', artist: 'Artist', videoId: 'abc123'),
          );

      expect(result, isNotNull);
      expect(result!.isSynced, isFalse);
      expect(result.text, 'just words');
      expect(result.attribution, 'Lyrics from Unison');
    });

    test('falls back to lyrics.ovh and keeps fetchLyrics format', () async {
      final client = MockClient((request) async {
        if (request.url.host == 'api.lyrics.ovh') {
          return _json({'lyrics': 'la la la'});
        }
        return _json([]);
      });
      final text = await LyricsManager(
        client: client,
        providers: const [],
      ).fetchLyrics('Artist', 'Song');
      expect(text, 'la la la\n\n© lyrics.ovh');
    });

    test('caches results, including misses', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return _json([], 404);
      });
      final manager = LyricsManager(client: client);
      expect(await manager.fetchLyrics('Artist', 'Song'), isNull);
      final firstRunCalls = calls;
      expect(await manager.fetchLyrics('Artist', 'Song'), isNull);
      expect(calls, firstRunCalls);
    });

    test('does not request slug based sites for non-Latin titles', () async {
      final hosts = <String>{};
      final client = MockClient((request) async {
        hosts.add(request.url.host);
        return _json([], 404);
      });
      await LyricsManager(client: client).fetchLyrics('فيروز', 'كيفك');
      expect(hosts.contains('www.paroles.net'), isFalse);
      expect(hosts.contains('www.lyricsmania.com'), isFalse);
      expect(hosts.contains('lrclib.net'), isTrue);
    });

    test('returns null for empty input', () async {
      expect(await LyricsManager().fetchLyrics('', 'x'), isNull);
    });
  });
}
