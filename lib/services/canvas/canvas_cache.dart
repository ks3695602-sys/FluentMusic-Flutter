/*
 * Portions derived from BitChord (kushagrasinghx/BitChord), GPL-3.0.
 * https://github.com/kushagrasinghx/BitChord
 */

import 'dart:io';

import 'package:musify/services/canvas/canvas_http.dart';
import 'package:path_provider/path_provider.dart';

/// Small disk cache for looping cover videos.
///
/// Files are stored in the app's support directory and oldest files are
/// removed once the 50 MB budget is exceeded. Cache lookup is by URL hash, so
/// provider-specific URLs are never exposed as filenames.
class CanvasCache {
  CanvasCache._();

  static final CanvasCache instance = CanvasCache._();
  static const int maxBytes = 50 * 1024 * 1024;

  Future<Directory>? _directory;

  Future<Directory> get _root async => _directory ??= _createDirectory();

  Future<Directory> _createDirectory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}canvas',
    );
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  /// Returns the cached file when present, otherwise downloads and stores a
  /// bounded MP4. HLS manifests are intentionally streamed directly instead.
  Future<File?> fileFor(String url) async {
    if (!_isCacheable(url)) return null;
    final directory = await _root;
    final file = File(
      '${directory.path}${Platform.pathSeparator}${_key(url)}.mp4',
    );
    if (await file.exists()) {
      await file.setLastModified(DateTime.now());
      return file;
    }

    final bytes = await CanvasHttp.getBytes(
      Uri.parse(url),
      maxBytes: 24 * 1024 * 1024,
      timeout: const Duration(seconds: 20),
    );
    if (bytes == null || bytes.isEmpty) return null;
    await file.writeAsBytes(bytes, flush: true);
    await _trim(directory);
    return file;
  }

  Future<int> sizeBytes() async {
    final directory = await _root;
    var total = 0;
    await for (final entity in directory.list()) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Future<void> clear() async {
    final directory = await _root;
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File) await entity.delete();
      }
    }
  }

  bool _isCacheable(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        !url.toLowerCase().contains('.m3u8') &&
        (uri.path.toLowerCase().endsWith('.mp4') ||
            uri.host.endsWith('resources.tidal.com'));
  }

  Future<void> _trim(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File) files.add(entity);
    }
    final records = <(File, int, DateTime)>[];
    var total = 0;
    for (final file in files) {
      final stat = await file.stat();
      total += stat.size;
      records.add((file, stat.size, stat.modified));
    }
    records.sort((a, b) => a.$3.compareTo(b.$3));
    for (final entry in records) {
      if (total <= maxBytes) break;
      try {
        await entry.$1.delete();
        total -= entry.$2;
      } on FileSystemException {
        // A player may still hold the file open; leave it until next trim.
      }
    }
  }

  String _key(String url) {
    var hash = 0x811c9dc5;
    for (final unit in url.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }
}
