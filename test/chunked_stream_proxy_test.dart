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

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/streaming/chunked_stream_proxy.dart';

void main() {
  group('range parsing', () {
    test('open-ended request becomes the whole file', () {
      expect(ChunkedStreamProxy.parseRange(null, 100), (0, 99));
      expect(ChunkedStreamProxy.parseRange('bytes=0-', 100), (0, 99));
    });

    test('bounded ranges are clamped to the file', () {
      expect(ChunkedStreamProxy.parseRange('bytes=10-19', 100), (10, 19));
      expect(ChunkedStreamProxy.parseRange('bytes=90-500', 100), (90, 99));
    });

    test('suffix ranges count from the end', () {
      expect(ChunkedStreamProxy.parseRange('bytes=-10', 100), (90, 99));
    });

    test('unsatisfiable ranges are refused', () {
      expect(ChunkedStreamProxy.parseRange('bytes=100-', 100), isNull);
      expect(ChunkedStreamProxy.parseRange('bytes=20-10', 100), isNull);
      expect(ChunkedStreamProxy.parseRange('bytes=-0', 100), isNull);
    });

    test('narrow clients get half-megabyte chunks', () {
      expect(
        ChunkedStreamProxy.chunkBytesFor(
          'https://rr1.googlevideo.com/videoplayback?c=ANDROID_VR&cver=1.65.10',
        ),
        ChunkedStreamProxy.narrowChunkBytes,
      );
      expect(
        ChunkedStreamProxy.chunkBytesFor(
          'https://rr1.googlevideo.com/videoplayback?c=IOS&cver=21.29.1',
        ),
        ChunkedStreamProxy.defaultChunkBytes,
      );
    });
  });

  group('loopback proxy', () {
    late HttpServer upstream;
    late Uint8List payload;
    final ranges = <String>[];

    setUp(() async {
      payload = Uint8List.fromList(
        List<int>.generate(2 * 1024 * 1024 + 77, (i) => i % 251),
      );
      ranges.clear();
      upstream = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      upstream.listen((request) async {
        final range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range ?? 'none');
        final response = request.response;

        final start = range == null
            ? 0
            : int.parse(range.substring('bytes='.length).split('-').first);
        final endText = range == null
            ? ''
            : range.substring('bytes='.length).split('-').last;
        final end = endText.isEmpty
            ? payload.length - 1
            : min(int.parse(endText), payload.length - 1);

        response.statusCode = range == null
            ? HttpStatus.ok
            : HttpStatus.partialContent;
        response.headers.contentType = ContentType('audio', 'mp4');
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${payload.length}',
        );
        response.headers.contentLength = end - start + 1;
        response.add(Uint8List.sublistView(payload, start, end + 1));
        await response.close();
      });
    });

    tearDown(() async {
      await ChunkedStreamProxy.instance.reset();
      await upstream.close(force: true);
    });

    Future<Uint8List> read(Uri uri, String range) async {
      final client = HttpClient();
      try {
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.rangeHeader, range);
        final response = await request.close();
        expect(response.statusCode, HttpStatus.partialContent);
        final builder = BytesBuilder(copy: false);
        await for (final data in response) {
          builder.add(data);
        }
        return builder.takeBytes();
      } finally {
        client.close(force: true);
      }
    }

    test('serves the whole stream from bounded upstream ranges', () async {
      final uri = await ChunkedStreamProxy.instance.register(
        songId: 'song-1',
        url: 'http://127.0.0.1:${upstream.port}/media',
        totalBytes: payload.length,
        contentType: 'audio/mp4',
      );
      expect(uri, isNotNull);

      final bytes = await read(uri!, 'bytes=0-');
      expect(bytes.length, payload.length);
      expect(bytes, payload);

      // Three chunks: 1 MiB, 1 MiB, then the remainder. Every upstream
      // request must be bounded — an open-ended one is what googlevideo
      // paces down to playback speed.
      expect(ranges.length, 3);
      for (final range in ranges) {
        expect(range, matches(RegExp(r'^bytes=\d+-\d+$')));
      }
    });

    test('a second read and a seek are served from the chunk cache', () async {
      final uri = await ChunkedStreamProxy.instance.register(
        songId: 'song-2',
        url: 'http://127.0.0.1:${upstream.port}/media',
        totalBytes: payload.length,
        contentType: 'audio/mp4',
      );
      await read(uri!, 'bytes=0-');
      final afterFirstRead = ranges.length;

      final seek = await read(uri, 'bytes=1500000-1600000');
      expect(seek, Uint8List.sublistView(payload, 1500000, 1600001));
      expect(ranges.length, afterFirstRead);
      expect(
        ChunkedStreamProxy.instance.cachedBytes,
        lessThanOrEqualTo(ChunkedStreamProxy.maxCachedBytes),
      );
    });

    test('an upstream refusal fails the request before any bytes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = HttpStatus.forbidden;
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final uri = await ChunkedStreamProxy.instance.register(
        songId: 'song-3',
        url: 'http://127.0.0.1:${server.port}/media',
        totalBytes: payload.length,
        contentType: 'audio/mp4',
      );
      expect(uri, isNotNull);

      final client = HttpClient();
      try {
        final request = await client.getUrl(uri!);
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-');
        final response = await request.close();
        await response.drain<void>();
        expect(response.statusCode, HttpStatus.forbidden);
      } finally {
        client.close(force: true);
      }
    });
  });
}
