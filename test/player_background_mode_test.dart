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

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/mornye_player/models/player_background_mode.dart';

void main() {
  group('PlayerBackgroundMode storage', () {
    test('round-trips every mode', () {
      for (final mode in PlayerBackgroundMode.values) {
        expect(
          PlayerBackgroundMode.fromStorage(mode.storageValue),
          mode,
          reason: mode.name,
        );
      }
    });

    test('ignores unknown and non-string values', () {
      expect(PlayerBackgroundMode.fromStorage('sepia'), isNull);
      expect(PlayerBackgroundMode.fromStorage(true), isNull);
      expect(PlayerBackgroundMode.fromStorage(null), isNull);
    });

    test('migrates the legacy mesh switch', () {
      expect(
        PlayerBackgroundMode.fromLegacyMesh(false),
        PlayerBackgroundMode.blurredAlbumArt,
      );
      expect(
        PlayerBackgroundMode.fromLegacyMesh(true),
        PlayerBackgroundMode.cinematic,
      );
      expect(
        PlayerBackgroundMode.fromLegacyMesh(null),
        PlayerBackgroundMode.cinematic,
      );
    });
  });
}
