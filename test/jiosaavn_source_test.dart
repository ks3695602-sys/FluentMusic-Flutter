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
import 'package:musify/services/sources/jiosaavn_source.dart';

void main() {
  group('JioSaavn media envelope', () {
    // A real "Tum Hi Ho" result captured from jiosaavn.com's web API. If the
    // envelope or the key ever changes, this test fails before a user finds
    // out that the fallback source has gone quiet.
    const encrypted =
        'ID2ieOjCrwfgWvL5sXl4B1ImC5QfbsDyRofh8YQPTqjR2tIxTYXqGEQHgqnNfseto'
        'uo4rsD0s4RZKObWAyHrEhw7tS9a8Gtq';

    test('opens the 96 kbps URL', () {
      expect(
        decryptJioSaavnMediaUrlForTest(encrypted),
        'https://aac.saavncdn.com/430/5c5ea5cc00e3bff45616013226f376fe_96.mp4',
      );
    });

    test('rejects a malformed envelope instead of throwing', () {
      expect(
        () => decryptJioSaavnMediaUrlForTest('not base64 at all!'),
        throwsA(anything),
      );
    });
  });
}