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

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:musify/services/logger_service.dart';

/// Serves a googlevideo stream to the player as a run of bounded ranges
/// instead of one open-ended read.
///
/// googlevideo paces a continuous response down to roughly playback speed:
/// ask for a whole track in one request and it arrives at about 15 kB/s,
/// barely ahead of the rate it is being consumed at, which is heard as a
/// stream that starts late and then stalls. Ask for the same bytes as bounded
/// ranges and each one is served at line rate. This is the behaviour BitChord
/// measured and implemented in its `ChunkedDataSource`; this class is the
/// Dart equivalent, sitting between `just_audio` and the CDN.
///
/// The player is handed a loopback URL and keeps using ordinary HTTP range
/// requests. Every upstream request this proxy makes is capped at one chunk,
/// so a seek costs one bounded read rather than a new open-ended stream.
class ChunkedStreamProxy {
  ChunkedStreamProxy._();

  static final ChunkedStreamProxy instance = ChunkedStreamProxy._();

  /// Largest single range googlevideo reliably serves at line rate.
  static const int defaultChunkBytes = 1024 * 1024;

  /// `ANDROID_VR` and `TVHTML5_SIMPLY` refuse ranges wider than this.
  static const int narrowChunkBytes = 512 * 1024;

  /// ZenMusic's range width for throttled streams.
  ///
  /// A throttled URL is paced by response length, so a wider bounded range is
  /// one request instead of ten. Only used when the URL was minted by the Zen
  /// fast path, where the client is known to accept it.
  static const int largeChunkBytes = 10379935;

  /// Chunks kept in memory per stream. Eight covers the first eight minutes
  /// of a 128 kbps track and makes seeking back into the intro instant.
  static const int maxCachedChunksPerStream = 8;

  /// A large chunk is ~10 MB, so three of them already fill most of the
  /// global budget. Keeping fewer stops one queue transition from evicting
  /// everything else.
  static const int maxLargeCachedChunksPerStream = 3;

  /// Hard ceiling for all chunk caches together. Oldest chunks are dropped
  /// first, so a long queue cannot turn the proxy into a memory leak.
  static const int maxCachedBytes = 32 * 1024 * 1024;

  /// Streams kept alive at once. A queue transition registers one new stream
  /// and the previous one stays warm for a seek back.
  static const int maxStreams = 12;

  static const Duration idleStreamTtl = Duration(minutes: 20);
  static const Duration _upstreamTimeout = Duration(seconds: 20);

  /// Gyawun's range-fetch retry policy: five units of error budget and half a
  /// second between attempts. A rate limit costs two units, a server error
  /// three, and any other transient failure one, so a hard 429 cannot spin the
  /// proxy for five full attempts.
  static const int _retryBudget = 5;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  final Logger _log = Logger();

  HttpServer? _server;
  final Map<String, _ProxyStream> _streams = {};
  final Map<String, _ProxyStream> _byToken = {};

  /// Keys whose first player flush has already been timed ("stream timing:
  /// first media bytes"), so the diagnosis logs exactly once per stream.
  final Set<String> _firstFlushTimed = {};
  final Random _random = Random.secure();
  int _nextStreamId = 0;
  int _consecutiveTransportFailures = 0;
  int _cachedBytes = 0;
  bool _enabled = true;

  /// Whether the proxy can run on this platform at all. Web has no
  /// `dart:io` sockets, and the audio stack is native-only anyway.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isLinux ||
          Platform.isWindows);

  /// Whether proxying is still worth attempting this session.
  bool get isEnabled => _enabled && isSupportedPlatform;

  /// One shared client, so every chunk reuses the same connection pool and
  /// DNS answer. Splitting the media fetch across fresh clients is what makes
  /// googlevideo see a different address family than the request that minted
  /// the URL.
  final HttpClient _client = HttpClient()
    ..autoUncompress = false
    ..connectionTimeout = const Duration(seconds: 10)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 6;

  /// Registers [url] for playback and returns the loopback URL to hand to the
  /// player, or null when the direct URL should be used instead.
  ///
  /// [totalBytes] and [contentType] come from the manifest when it is still in
  /// memory. A cached URL has neither, so the length is discovered with a
  /// one-byte ranged request before the first response is written.
  Future<Uri?> register({
    required String songId,
    required String url,
    Map<String, String>? headers,
    int? totalBytes,
    String? contentType,
    int? chunkBytes,
  }) async {
    if (!isEnabled) return null;

    final upstream = Uri.tryParse(url);
    if (upstream == null || !upstream.hasScheme) return null;

    final key = '$songId|$url';
    var stream = _streams[key];
    if (stream == null) {
      stream = _ProxyStream(
        key: key,
        songId: songId,
        token: _newToken(),
        url: upstream,
        headers: headers ?? const {},
        totalBytes: totalBytes,
        contentType: contentType,
        chunkBytes: chunkBytes ?? chunkBytesFor(url),
      );
      _streams[key] = stream;
      _byToken[stream.token] = stream;
      _evictStale();
    } else {
      stream.totalBytes ??= totalBytes;
      stream.contentType ??= contentType;
      if (headers != null && headers.isNotEmpty) stream.headers = headers;
      stream.touched = DateTime.now();
    }

    if (stream.totalBytes == null) {
      final length = await _probeLength(stream)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (length == null) {
        _forgetStream(stream);
        return null;
      }
    }

    final server = await _ensureServer();
    if (server == null) return null;

    return Uri.parse(
      'http://${server.address.address}:${server.port}/s/${stream.token}',
    );
  }

  /// Warms the first chunk of an upcoming track, so the transition into it
  /// starts from memory instead of waiting on a fresh CDN round trip.
  ///
  /// BitChord's `AudioCache.prefetchDirect` does the same for the next queue
  /// row. Failures are silent: this is an optimisation, never a requirement.
  Future<void> prefetch({
    required String songId,
    required String url,
    Map<String, String>? headers,
    int? totalBytes,
    String? contentType,
    int? chunkBytes,
  }) async {
    if (!isEnabled) return;
    final upstream = Uri.tryParse(url);
    if (upstream == null || !upstream.host.endsWith('googlevideo.com')) return;

    try {
      final registered = await register(
        songId: songId,
        url: url,
        headers: headers,
        totalBytes: totalBytes,
        contentType: contentType,
        chunkBytes: chunkBytes,
      );
      if (registered == null) return;

      final stream = _streamByToken(registered.pathSegments.last);
      if (stream == null) return;
      await _chunk(stream, 0, stream.totalBytes!);
    } catch (e, stackTrace) {
      _log.log(
        'Chunk prefetch failed for $songId',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// The chunk size googlevideo will serve for [url]'s client.
  @visibleForTesting
  static int chunkBytesFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.host.endsWith('googlevideo.com')) {
      return defaultChunkBytes;
    }
    final name = (uri.queryParameters['c'] ?? '').toUpperCase();
    return name == 'ANDROID_VR' || name.startsWith('TVHTML5_SIMPLY')
        ? narrowChunkBytes
        : defaultChunkBytes;
  }

  String _newToken() {
    final salt = _random.nextInt(0x7fffffff).toRadixString(36);
    return '${_nextStreamId++}-$salt';
  }

  Future<HttpServer?> _ensureServer() async {
    final existing = _server;
    if (existing != null) return existing;

    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.autoCompress = false;
      server.listen(
        (request) => unawaited(_handleRequest(request)),
        onError: (Object error, StackTrace stackTrace) {
          _log.log(
            'Loopback stream server error',
            error: error,
            stackTrace: stackTrace,
          );
        },
      );
      _server = server;
      return server;
    } catch (e, stackTrace) {
      _enabled = false;
      _log.log(
        'Could not start the loopback stream server; using direct URLs',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  _ProxyStream? _streamByToken(String token) => _byToken[token];

  void _forgetStream(_ProxyStream stream) {
    for (final bytes in stream.chunks.values) {
      _cachedBytes -= bytes.length;
    }
    stream.chunks.clear();
    _streams.remove(stream.key);
    _byToken.remove(stream.token);
  }

  void _evictStale() {
    final now = DateTime.now();
    final stale = _streams.values
        .where((stream) => now.difference(stream.touched) > idleStreamTtl)
        .toList();
    for (final stream in stale) {
      _forgetStream(stream);
    }

    while (_streams.length > maxStreams) {
      var oldest = _streams.values.first;
      for (final stream in _streams.values) {
        if (stream.touched.isBefore(oldest.touched)) oldest = stream;
      }
      _forgetStream(oldest);
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final token = request.uri.pathSegments.isEmpty
        ? ''
        : request.uri.pathSegments.last;
    final stream = _streamByToken(token);
    if (stream == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    stream.touched = DateTime.now();

    try {
      await _serve(request, stream, Stopwatch()..start());
    } catch (e) {
      // A player that stops reading closes the socket; that is a normal seek
      // or a track change, not an error worth logging at full volume.
      if (e is! SocketException && e is! HttpException) {
        _log.log('Stream proxy request failed', error: e);
      }
      try {
        await request.response.close();
      } catch (_) {
        // Already closed by the player.
      }
    }
  }

  Future<void> _serve(
    HttpRequest request,
    _ProxyStream stream,
    Stopwatch sinceRequest,
  ) async {
    final response = request.response;

    if (request.method != 'GET' && request.method != 'HEAD') {
      response.statusCode = HttpStatus.methodNotAllowed;
      await response.close();
      return;
    }

    final length = await _ensureMetadata(stream);
    if (length == null) {
      // Expired or refused URL: fail before any bytes are written so the
      // player errors out and the app retries with a freshly minted URL.
      response.statusCode = HttpStatus.forbidden;
      await response.close();
      return;
    }

    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    final range = _parseRange(rangeHeader, length);
    if (range == null) {
      response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      response.headers.set(HttpHeaders.contentRangeHeader, 'bytes */$length');
      await response.close();
      return;
    }

    final start = range.$1;
    final end = range.$2;
    final isPartial = rangeHeader != null && rangeHeader.isNotEmpty;

    response.statusCode = isPartial ? HttpStatus.partialContent : HttpStatus.ok;
    response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      stream.contentType ?? 'audio/mp4',
    );
    response.headers.contentLength = end - start + 1;
    if (isPartial) {
      response.headers.set(
        HttpHeaders.contentRangeHeader,
        'bytes $start-$end/$length',
      );
    }

    if (request.method == 'HEAD') {
      await response.close();
      return;
    }

    var position = start;
    while (position <= end) {
      final index = position ~/ stream.chunkBytes;
      final chunk = await _chunk(stream, index, length);
      if (chunk == null) {
        if (position == start) {
          // Nothing was written yet, so the response can still become a clean
          // 403 and the player can retry with a freshly minted URL.
          response.statusCode = HttpStatus.forbidden;
          response.headers.contentLength = 0;
          response.headers.removeAll(HttpHeaders.contentRangeHeader);
        }
        break;
      }

      final chunkStart = index * stream.chunkBytes;
      final from = position - chunkStart;
      final available = min(chunk.length, end - chunkStart + 1);
      if (available <= from) break;

      response.add(Uint8List.sublistView(chunk, from, available));
      await response.flush();
      if (position == start && _firstFlushTimed.add(stream.key)) {
        _log.log(
          'stream timing: first media bytes for ${stream.songId} '
          'at ${sinceRequest.elapsedMilliseconds}ms '
          '(range $start-$end, player request)',
        );
      }
      position = chunkStart + available;
    }

    await response.close();
  }

  /// Total length of the stream, probed once with a one-byte range request
  /// when the manifest is no longer in memory.
  Future<int?> _ensureMetadata(_ProxyStream stream) async {
    final known = stream.totalBytes;
    if (known != null) return known;
    if (stream.metadataFailed) return null;
    return _probeLength(stream);
  }

  Future<int?> _probeLength(_ProxyStream stream) async {
    if (stream.metadataFailed) return null;
    try {
      final request = await _client.getUrl(stream.url);
      _applyHeaders(request.headers, stream.headers);
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-0');

      final response = await request.close().timeout(_upstreamTimeout);
      final contentRange = response.headers.value(
        HttpHeaders.contentRangeHeader,
      );
      final contentLength = response.contentLength;
      final contentType = response.headers.contentType?.mimeType;
      final status = response.statusCode;
      await response.drain<void>();

      if (status == HttpStatus.forbidden ||
          status == HttpStatus.notFound ||
          status == HttpStatus.gone) {
        stream.metadataFailed = true;
        return null;
      }
      if (status != HttpStatus.partialContent && status != HttpStatus.ok) {
        stream.metadataFailed = true;
        return null;
      }

      final length =
          _lengthFromContentRange(contentRange) ??
          (contentLength > 0 ? contentLength : null);
      if (length == null || length <= 0) {
        stream.metadataFailed = true;
        return null;
      }

      stream.totalBytes = length;
      stream.contentType ??= contentType;
      if (status == HttpStatus.ok) {
        // The host ignored the range. Chunking cannot work against it.
        stream.metadataFailed = true;
        return null;
      }
      return length;
    } catch (e) {
      stream.metadataFailed = true;
      _log.log('Stream length probe failed', error: e);
      return null;
    }
  }

  static void _applyHeaders(HttpHeaders target, Map<String, String> headers) {
    for (final entry in headers.entries) {
      target.set(entry.key, entry.value);
    }
  }

  static int? _lengthFromContentRange(String? value) {
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    if (slash < 0) return null;
    return int.tryParse(value.substring(slash + 1).trim());
  }

  /// Parses a `Range` header into an inclusive `(start, end)` pair, clamped to
  /// [length]. Returns null when the request cannot be satisfied.
  @visibleForTesting
  static (int, int)? parseRange(String? header, int length) =>
      _parseRange(header, length);

  static (int, int)? _parseRange(String? header, int length) {
    if (length <= 0) return null;
    if (header == null || header.trim().isEmpty) return (0, length - 1);

    final value = header.trim();
    if (!value.startsWith('bytes=')) return (0, length - 1);

    final spec = value.substring('bytes='.length).split(',').first.trim();
    final dash = spec.indexOf('-');
    if (dash < 0) return null;

    final startText = spec.substring(0, dash).trim();
    final endText = spec.substring(dash + 1).trim();

    int start;
    int end;
    if (startText.isEmpty) {
      final suffix = int.tryParse(endText);
      if (suffix == null || suffix <= 0) return null;
      start = max(0, length - suffix);
      end = length - 1;
    } else {
      final parsedStart = int.tryParse(startText);
      if (parsedStart == null || parsedStart < 0) return null;
      start = parsedStart;
      end = endText.isEmpty ? length - 1 : (int.tryParse(endText) ?? -1);
    }

    if (start >= length) return null;
    if (end < start) return null;
    if (end >= length) end = length - 1;
    return (start, end);
  }

  /// Returns chunk [index] from memory, downloading it as one bounded range
  /// when it is not cached. Concurrent requests for the same chunk share one
  /// download.
  Future<Uint8List?> _chunk(_ProxyStream stream, int index, int length) {
    final cached = stream.chunks[index];
    if (cached != null) return Future.value(cached);

    final pending = stream.pending[index];
    if (pending != null) return pending;

    final future = _downloadChunk(stream, index, length);
    stream.pending[index] = future;
    return future.whenComplete(() => stream.pending.remove(index));
  }

  Future<Uint8List?> _downloadChunk(
    _ProxyStream stream,
    int index,
    int length,
  ) async {
    final start = index * stream.chunkBytes;
    final end = min(start + stream.chunkBytes, length) - 1;
    if (start >= length) return null;

    final bytes = await _fetchRange(stream, start, end);
    if (bytes == null) return null;

    final cacheLimit = stream.chunkBytes >= largeChunkBytes
        ? maxLargeCachedChunksPerStream
        : maxCachedChunksPerStream;
    while (stream.chunks.length >= cacheLimit) {
      _dropChunk(stream, stream.chunks.keys.first);
    }
    stream.chunks[index] = bytes;
    _cachedBytes += bytes.length;
    _trimCache();
    return bytes;
  }

  void _dropChunk(_ProxyStream stream, int index) {
    final removed = stream.chunks.remove(index);
    if (removed != null) _cachedBytes -= removed.length;
  }

  /// Drops the oldest chunk of the least recently used stream until the
  /// global cache fits its budget again.
  void _trimCache() {
    while (_cachedBytes > maxCachedBytes) {
      _ProxyStream? oldest;
      for (final stream in _streams.values) {
        if (stream.chunks.isEmpty) continue;
        if (oldest == null || stream.touched.isBefore(oldest.touched)) {
          oldest = stream;
        }
      }
      if (oldest == null) {
        _cachedBytes = 0;
        break;
      }
      _dropChunk(oldest, oldest.chunks.keys.first);
    }
  }

  /// Fetches one bounded range, resuming from the last received byte after a
  /// transient failure.
  ///
  /// This is Gyawun's `AudioStreamClient` retry shape ported to the loopback
  /// proxy: the same five-unit error budget, the same 500 ms pause, and the
  /// same cost tiers (rate limit 2, server error 3, anything else 1). The
  /// difference is that a partial body is kept, so a connection that drops
  /// halfway through a chunk resumes instead of downloading it again.
  Future<Uint8List?> _fetchRange(
    _ProxyStream stream,
    int start,
    int end,
  ) async {
    final expected = end - start + 1;
    final builder = BytesBuilder(copy: false);
    var offset = start;
    var budget = _retryBudget;
    var attempts = 0;

    while (offset <= end) {
      attempts++;
      var cost = 1;
      var retry = false;
      var completed = false;

      try {
        final request = await _client.getUrl(stream.url);
        _applyHeaders(request.headers, stream.headers);
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-$end');

        final response = await request.close().timeout(_upstreamTimeout);
        final status = response.statusCode;

        if (status == HttpStatus.forbidden ||
            status == HttpStatus.notFound ||
            status == HttpStatus.gone) {
          await response.drain<void>();
          // The URL expired. Not a transport problem: the next playback
          // attempt mints a new one.
          stream.metadataFailed = true;
          _log.log(
            'Chunk fetch refused for ${stream.songId} at $offset-$end '
            '(HTTP $status)',
          );
          return null;
        }

        if (status == HttpStatus.tooManyRequests) {
          await response.drain<void>();
          cost = 2;
          retry = true;
          _log.log(
            'stream timing: chunk retry ${stream.songId} at $offset '
            'after HTTP 429 (attempt $attempts)',
          );
        } else if (status >= 500) {
          await response.drain<void>();
          cost = 3;
          retry = true;
          _log.log(
            'stream timing: chunk retry ${stream.songId} at $offset '
            'after HTTP $status (attempt $attempts)',
          );
        } else if (status != HttpStatus.partialContent &&
            status != HttpStatus.ok) {
          await response.drain<void>();
          cost = 3;
          retry = true;
          _log.log(
            'stream timing: chunk retry ${stream.songId} at $offset '
            'after HTTP $status (attempt $attempts)',
          );
        } else if (status == HttpStatus.ok && offset != 0) {
          await response.drain<void>();
          // The host ignored the range; the body would start at byte zero.
          stream.metadataFailed = true;
          return null;
        } else {
          await for (final data in response) {
            builder.add(data);
            if (builder.length >= expected) break;
          }

          _noteTransportSuccess();
          if (builder.length >= expected) {
            completed = true;
          } else {
            // A cleanly closed but short response is still a failure; resume
            // from where it stopped instead of accepting a truncated chunk.
            cost = 1;
            retry = true;
            _log.log(
              'stream timing: chunk retry ${stream.songId} at $offset '
              'after a short body (attempt $attempts)',
            );
          }
        }
      } catch (e) {
        cost = 1;
        retry = true;
        _noteTransportFailure();
        _log.log(
          'Chunk fetch attempt $attempts failed for ${stream.songId} '
          'at $offset-$end',
          error: e,
        );
      }

      if (completed || !retry) break;

      budget -= cost;
      if (budget <= 0) {
        _log.log(
          'stream timing: chunk fetch gave up for ${stream.songId} '
          'at $offset after $attempts attempts',
        );
        return null;
      }

      offset = start + builder.length;
      if (offset > end) break;
      await Future.delayed(_retryDelay);
    }

    final bytes = builder.takeBytes();
    if (bytes.isEmpty) return null;

    return bytes.length > expected
        ? Uint8List.sublistView(bytes, 0, expected)
        : bytes;
  }

  void _noteTransportSuccess() {
    _consecutiveTransportFailures = 0;
  }

  /// Three transport failures in a row (DNS, TLS, socket) mean the loopback
  /// hop itself is not viable on this device; playback should fall back to
  /// direct URLs instead of retrying through a broken proxy forever.
  void _noteTransportFailure() {
    _consecutiveTransportFailures++;
    if (_consecutiveTransportFailures >= 3 && _enabled) {
      _enabled = false;
      _log.log(
        'Disabling the loopback stream proxy after repeated transport '
        'failures; falling back to direct URLs',
      );
    }
  }

  /// Test hook: forget every registered stream and start the server again.
  @visibleForTesting
  Future<void> reset() async {
    _streams.clear();
    _byToken.clear();
    _cachedBytes = 0;
    _consecutiveTransportFailures = 0;
    _enabled = true;
    await _server?.close(force: true);
    _server = null;
  }

  /// Bytes currently held in chunk caches. Test hook.
  @visibleForTesting
  int get cachedBytes => _cachedBytes;
}

class _ProxyStream {
  _ProxyStream({
    required this.key,
    required this.songId,
    required this.token,
    required this.url,
    required this.headers,
    required this.chunkBytes,
    this.totalBytes,
    this.contentType,
  });

  final String key;
  final String songId;
  final String token;
  final Uri url;
  final int chunkBytes;
  Map<String, String> headers;
  int? totalBytes;
  String? contentType;
  DateTime touched = DateTime.now();
  bool metadataFailed = false;

  /// Chunk index to bytes, oldest first.
  final Map<int, Uint8List> chunks = {};
  final Map<int, Future<Uint8List?>> pending = {};
}
