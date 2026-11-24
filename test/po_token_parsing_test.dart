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

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/youtube/po_token_parsing.dart';

void main() {
  group('parseChallengeData', () {
    test('reads a plain challenge array', () {
      final challenge = [
        'message-id',
        ['interpreter-js'],
        ['https://example.test/vm.js'],
        'interpreter-hash',
        'program-text',
        'globalVmName',
        'client-experiments',
        'experiments-blob',
      ];

      final parsed = parseChallengeData(jsonEncode([challenge]));

      expect(parsed.messageId, 'message-id');
      expect(parsed.interpreterJavascript, 'interpreter-js');
      expect(parsed.interpreterTrustedResourceUrl, 'https://example.test/vm.js');
      expect(parsed.interpreterHash, 'interpreter-hash');
      expect(parsed.program, 'program-text');
      expect(parsed.globalName, 'globalVmName');
      expect(parsed.clientExperimentsStateBlob, 'experiments-blob');
    });

    test('descrambles the shifted challenge', () {
      final challenge = [
        'message-id',
        [null, 'interpreter-js'],
        [null, 'https://vm.test'],
        'hash',
        'program',
        'vm',
        '',
        'blob',
      ];
      final scrambled = _scramble(jsonEncode(challenge));

      final parsed = parseChallengeData(jsonEncode(['ignored', scrambled]));

      expect(parsed.messageId, 'message-id');
      expect(parsed.interpreterJavascript, 'interpreter-js');
      expect(parsed.globalName, 'vm');
    });

    test('rejects an empty answer', () {
      expect(() => parseChallengeData('[]'), throwsFormatException);
    });
  });

  group('parseIntegrityTokenData', () {
    test('renders a Uint8Array literal and reads the lifetime', () {
      final raw = jsonEncode([
        base64.encode(Uint8List.fromList([1, 2, 3, 250])),
        7200,
      ]);

      final parsed = parseIntegrityTokenData(raw);

      expect(parsed.integrityTokenLiteral, 'new Uint8Array([1,2,3,250])');
      expect(parsed.ttlSeconds, 7200);
    });

    test('defaults the lifetime when YouTube omits it', () {
      final raw = jsonEncode([base64.encode([9])]);

      expect(parseIntegrityTokenData(raw).ttlSeconds, 3600);
    });
  });

  group('byte helpers', () {
    test('stringToUint8Array encodes UTF-8', () {
      expect(
        stringToUint8Array('ab'),
        'new Uint8Array([97,98])',
      );
    });

    test('uint8ListToBase64 produces a URL-safe token', () {
      final bytes = [251, 255, 0, 1];
      final encoded = uint8ListToBase64(bytes.join(','));

      expect(encoded, isNot(contains('+')));
      expect(encoded, isNot(contains('/')));
      expect(uint8ListToBase64(bytes.join(',')), encoded);
    });

    test('ignores malformed byte entries', () {
      expect(uint8ListToBase64('1,oops,2'), isNotEmpty);
    });
  });
}

/// Adds 97 to each byte, the way YouTube scrambles the challenge.
String _scramble(String value) {
  final bytes = utf8.encode(value);
  final shifted = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    shifted[i] = (bytes[i] - 97) & 0xff;
  }
  return base64.encode(shifted).replaceAll('+', '-').replaceAll('/', '_');
}