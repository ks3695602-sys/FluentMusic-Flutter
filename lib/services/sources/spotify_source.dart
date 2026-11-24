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

import 'package:musify/services/sources/music_source.dart';

/// Spotify, listed honestly.
///
/// Spotify's audio is Widevine-protected and only served to an authenticated
/// SDK session; there is no anonymous audio URL to fetch, so it cannot be a
/// fallback stream without embedding Spotify's own player. The catalogue and
/// playlist import can be built on the Web API, but that is a separate
/// feature, not a stream resolver.
///
/// It is registered so Settings shows where the source stands instead of
/// leaving people guessing why "add Spotify" produces nothing.
class SpotifySource implements MusicSource {
  @override
  String get id => 'spotify';

  @override
  String get name => 'Spotify';

  @override
  bool get supportsStreaming => false;

  @override
  String get limitation =>
      'Spotify audio is DRM-protected and only plays inside Spotify\'s own '
      'SDK. Catalogue import can be added, streaming cannot.';

  @override
  Future<String?> resolveStreamUrl({
    required String title,
    required String artist,
    Duration? duration,
  }) async =>
      null;
}