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

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/models/explore_feed.dart';

void main() {
  group('exploreShortCategories', () {
    test('mixes the three discovery buckets in order', () {
      expect(exploreShortCategories, ['New', 'Trending', 'Evergreen']);
    });
  });

  group('normalizeExploreSong', () {
    test('keeps a complete song and tags its category', () {
      final song = normalizeExploreSong(
        {
          'ytid': 'abc123',
          'title': '  Nights  ',
          'artist': 'Frank Ocean',
          'highResImage': 'https://img/high.jpg',
          'lowResImage': 'https://img/low.jpg',
        },
        category: 'Trending',
      );

      expect(song, isNotNull);
      expect(song!['ytid'], 'abc123');
      expect(song['title'], 'Nights');
      expect(song['artist'], 'Frank Ocean');
      expect(song['highResImage'], 'https://img/high.jpg');
      expect(song['lowResImage'], 'https://img/low.jpg');
      expect(song['exploreCategory'], 'Trending');
    });

    test('falls back for a missing artist and artwork', () {
      final song = normalizeExploreSong({
        'ytid': 'xyz',
        'title': 'Untitled',
        'image': 'https://img/only.jpg',
      });

      expect(song, isNotNull);
      expect(song!['artist'], 'Unknown artist');
      expect(song['highResImage'], 'https://img/only.jpg');
      expect(song['lowResImage'], 'https://img/only.jpg');
      expect(song['image'], 'https://img/only.jpg');
      expect(song.containsKey('exploreCategory'), isFalse);
    });

    test('rejects entries without a playable id or title', () {
      expect(normalizeExploreSong(null), isNull);
      expect(normalizeExploreSong('not a map'), isNull);
      expect(
        normalizeExploreSong({'title': 'No id'}),
        isNull,
      );
      expect(
        normalizeExploreSong({'ytid': 'abc'}),
        isNull,
      );
      expect(
        normalizeExploreSong({'ytid': '   ', 'title': 'Blank id'}),
        isNull,
      );
    });
  });

  group('normalizeExplorePlaylist', () {
    test('keeps a playlist with a title and artwork', () {
      final playlist = normalizeExplorePlaylist({
        'ytid': 'pl1',
        'title': ' Top Hits ',
        'image': 'https://img/pl.jpg',
      });

      expect(playlist, isNotNull);
      expect(playlist!['ytid'], 'pl1');
      expect(playlist['title'], 'Top Hits');
      expect(playlist['image'], 'https://img/pl.jpg');
      expect(playlist['highResImage'], 'https://img/pl.jpg');
      expect(playlist['lowResImage'], 'https://img/pl.jpg');
    });

    test('falls back to the high resolution artwork', () {
      final playlist = normalizeExplorePlaylist({
        'ytid': 'pl2',
        'title': 'Chill',
        'highResImage': 'https://img/high.jpg',
      });

      expect(playlist, isNotNull);
      expect(playlist!['image'], 'https://img/high.jpg');
    });

    test('rejects playlists that cannot render a banner', () {
      expect(normalizeExplorePlaylist(null), isNull);
      expect(
        normalizeExplorePlaylist({'ytid': 'pl3', 'title': 'No art'}),
        isNull,
      );
      expect(
        normalizeExplorePlaylist({'ytid': 'pl4', 'image': 'https://img'}),
        isNull,
      );
      expect(
        normalizeExplorePlaylist({'title': 'No id', 'image': 'https://img'}),
        isNull,
      );
    });
  });

  group('mixExploreSongs', () {
    Map<String, dynamic> song(String id) => {'ytid': id};

    test('rotates through every group instead of draining one', () {
      final mixed = mixExploreSongs(
        [
          [song('new1'), song('new2')],
          [song('trend1'), song('trend2')],
          [song('ever1'), song('ever2')],
        ],
        const ['New', 'Trending', 'Evergreen'],
        limit: 6,
      );

      expect(
        mixed.map((entry) => entry['ytid']),
        ['new1', 'trend1', 'ever1', 'new2', 'trend2', 'ever2'],
      );
      expect(
        mixed.map((entry) => entry['exploreCategory']),
        ['New', 'Trending', 'Evergreen', 'New', 'Trending', 'Evergreen'],
      );
    });

    test('drops duplicate ids across groups', () {
      final mixed = mixExploreSongs(
        [
          [song('shared'), song('new1')],
          [song('shared'), song('trend1')],
          [song('ever1')],
        ],
        const ['New', 'Trending', 'Evergreen'],
        limit: 12,
      );

      final ids = mixed.map((entry) => entry['ytid']).toList();
      expect(ids, ['shared', 'ever1', 'new1', 'trend1']);
      expect(ids.toSet().length, ids.length);
    });

    test('stops at the limit', () {
      final mixed = mixExploreSongs(
        [
          [song('a1'), song('a2'), song('a3')],
          [song('b1'), song('b2'), song('b3')],
        ],
        const ['New', 'Trending'],
        limit: 3,
      );

      expect(mixed.map((entry) => entry['ytid']), ['a1', 'b1', 'a2']);
    });

    test('handles missing labels and empty input', () {
      expect(mixExploreSongs(const [], const ['New']), isEmpty);
      expect(mixExploreSongs([[song('a')]], const [], limit: 0), isEmpty);

      final unlabelled = mixExploreSongs(
        [
          [song('a')],
        ],
        const [],
      );
      expect(unlabelled.single.containsKey('exploreCategory'), isFalse);
    });

    test('skips entries without a video id', () {
      final mixed = mixExploreSongs(
        [
          [
            <String, dynamic>{'title': 'no id'},
            song('ok'),
          ],
        ],
        const ['New'],
      );

      expect(mixed.map((entry) => entry['ytid']), ['ok']);
    });
  });
}
