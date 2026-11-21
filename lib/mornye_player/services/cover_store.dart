import 'dart:io';

import 'package:path/path.dart' as p;

/// Mornye's durable store for `network://` cover references.
///
/// FluentMusic's covers are either http URLs (handled by [CoverCacheManager])
/// or plain files, so nothing here is a `network://` reference and the store
/// is never asked to fetch. Local files still resolve as themselves.
class CoverStore {
  CoverStore();

  static final CoverStore instance = CoverStore();

  /// Only Mornye's `network://` song covers need the store.
  static bool fetches(String? ref) =>
      ref != null && ref.startsWith('network://');

  /// The stored file for [ref], without touching the disk. FluentMusic keeps
  /// no index, so nothing is known before a read.
  String? indexedFile(String? ref) => null;

  /// The durable local file for [ref]. A plain path is returned when it
  /// exists; a `network://` reference has no store here.
  Future<String?> file(String? ref) async {
    if (ref == null || ref.isEmpty || fetches(ref)) return null;
    final path = ref.startsWith('file://')
        ? Uri.tryParse(ref)?.toFilePath()
        : (p.isAbsolute(ref) ? ref : null);
    if (path == null) return null;
    return await File(path).exists() ? path : null;
  }
}