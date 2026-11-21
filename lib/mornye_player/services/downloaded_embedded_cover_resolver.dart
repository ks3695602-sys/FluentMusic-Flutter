import 'package:flutter/foundation.dart';

/// Mornye reads the picture inside a downloaded song file and caches it.
///
/// FluentMusic shows the cover its metadata service already found, so there is
/// nothing to extract or preview here. Callers fall back to the cover they
/// were given.
class DownloadedEmbeddedCoverResolver {
  DownloadedEmbeddedCoverResolver._();

  /// Notifies when a song's embedded cover preview changed.
  static final ChangeNotifier previewsCleared = ChangeNotifier();

  /// The embedded cover of [filePath] if one is already known, else null.
  static String? resolve(String filePath, {VoidCallback? onChanged}) => null;

  /// Extracts the picture from [filePath]. Nothing is extracted here.
  static Future<String?> resolveOrExtract(String filePath) async => null;
}