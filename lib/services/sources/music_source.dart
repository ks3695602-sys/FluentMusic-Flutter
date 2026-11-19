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

import 'package:musify/main.dart' show logger;

/// One place a track can be streamed from.
///
/// YouTube Music stays the primary source and is not registered here: the
/// existing InnerTube ladder owns it. Everything else is additive — a provider
/// is only asked when the primary ladder refuses a track, and a provider that
/// cannot stream says so instead of pretending.
abstract interface class MusicSource {
  String get id;
  String get name;

  /// Whether this source can hand back an audio URL.
  bool get supportsStreaming;

  /// Why a source that is listed cannot stream, for the Settings copy.
  String? get limitation;

  /// Resolves a playable URL for a track, or null when it has no match.
  Future<String?> resolveStreamUrl({
    required String title,
    required String artist,
    Duration? duration,
  });
}

/// The sources that can be asked after YouTube has refused a track.
class SourceRegistry {
  SourceRegistry._();

  static final List<MusicSource> _sources = [];

  static List<MusicSource> get sources => List.unmodifiable(_sources);

  static void register(MusicSource source) {
    if (_sources.any((existing) => existing.id == source.id)) return;
    _sources.add(source);
  }

  /// The first streamable source that recognises [title] by [artist].
  static Future<String?> resolveFallback({
    required String title,
    required String artist,
    Duration? duration,
  }) async {
    if (title.trim().isEmpty || artist.trim().isEmpty) return null;

    for (final source in _sources) {
      if (!source.supportsStreaming) continue;
      try {
        final url = await source.resolveStreamUrl(
          title: title,
          artist: artist,
          duration: duration,
        );
        if (url != null && url.isNotEmpty) {
          logger.log('Stream served by ${source.name} for "$title"');
          return url;
        }
      } catch (error) {
        logger.log('${source.name} failed for "$title"', error: error);
      }
    }
    return null;
  }
}