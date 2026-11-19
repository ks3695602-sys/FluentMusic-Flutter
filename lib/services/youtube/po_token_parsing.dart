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

/// Parsing helpers for YouTube's BotGuard ("WebPO") endpoints.
///
/// Adapted from BitChord's `JavaScriptUtil.kt` (GPL-3.0), itself following
/// BgUtils. Deliberately free of Flutter imports so the decoding can be unit
/// tested on a plain Dart VM.

/// The API key the BotGuard endpoints expect in `x-goog-api-key`.
const botguardApiKey = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';

/// The fixed request key `/api/jnn/v1/Create` and `/GenerateIT` take.
const botguardRequestKey = 'O43z0dpjhgX20SCx4KAo';

const _createEndpoint = 'https://www.youtube.com/api/jnn/v1/Create';
const _generateItEndpoint = 'https://www.youtube.com/api/jnn/v1/GenerateIT';

Uri get botguardCreateUri => Uri.parse(_createEndpoint);
Uri get botguardGenerateItUri => Uri.parse(_generateItEndpoint);

/// The headers both BotGuard endpoints are asked with.
const botguardHeaders = <String, String>{
  'Accept': 'application/json',
  'Content-Type': 'application/json+protobuf',
  'x-goog-api-key': botguardApiKey,
  'x-user-agent': 'grpc-web-javascript/0.1',
};

/// The challenge object the page's `runBotGuard()` understands.
class BotGuardChallenge {
  const BotGuardChallenge({
    required this.messageId,
    required this.interpreterJavascript,
    required this.interpreterTrustedResourceUrl,
    required this.interpreterHash,
    required this.program,
    required this.globalName,
    required this.clientExperimentsStateBlob,
  });

  final String messageId;
  final String? interpreterJavascript;
  final String? interpreterTrustedResourceUrl;
  final String interpreterHash;
  final String program;
  final String globalName;
  final String clientExperimentsStateBlob;

  Map<String, dynamic> toJson() => {
        'messageId': messageId,
        'interpreterJavascript': {
          'privateDoNotAccessOrElseSafeScriptWrappedValue':
              interpreterJavascript,
          'privateDoNotAccessOrElseTrustedResourceUrlWrappedValue':
              interpreterTrustedResourceUrl,
        },
        'interpreterHash': interpreterHash,
        'program': program,
        'globalName': globalName,
        'clientExperimentsStateBlob': clientExperimentsStateBlob,
      };
}

/// Decodes the `/Create` response into a [BotGuardChallenge].
///
/// The answer is either `[challenge]` or `[scrambled, challenge]`, where the
/// second element is base64 whose bytes are shifted by 97.
BotGuardChallenge parseChallengeData(String raw) {
  final scrambled = jsonDecode(raw);
  if (scrambled is! List || scrambled.isEmpty) {
    throw const FormatException('BotGuard Create answered no challenge');
  }

  List<dynamic> challenge;
  if (scrambled.length > 1 && scrambled[1] is String) {
    final descrambled = _descramble(scrambled[1] as String);
    final decoded = jsonDecode(descrambled);
    if (decoded is! List) {
      throw const FormatException('BotGuard challenge was not a list');
    }
    challenge = decoded;
  } else {
    final first = scrambled[0];
    if (first is! List) {
      throw const FormatException('BotGuard challenge was not a list');
    }
    challenge = first;
  }

  String text(int index) {
    if (index >= challenge.length) return '';
    final value = challenge[index];
    if (value is String) return value;
    if (value is num) return value.toString();
    return '';
  }

  String? firstString(int index) {
    if (index >= challenge.length) return null;
    final value = challenge[index];
    if (value is List) {
      for (final entry in value) {
        if (entry is String) return entry;
      }
    }
    return null;
  }

  return BotGuardChallenge(
    messageId: text(0),
    interpreterJavascript: firstString(1),
    interpreterTrustedResourceUrl: firstString(2),
    interpreterHash: text(3),
    program: text(4),
    globalName: text(5),
    clientExperimentsStateBlob: text(7),
  );
}

/// Decodes the `/GenerateIT` answer into a JS `Uint8Array` literal and the
/// token's lifetime in seconds.
({String integrityTokenLiteral, int ttlSeconds}) parseIntegrityTokenData(
    String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List || decoded.isEmpty) {
    throw const FormatException('GenerateIT answered no integrity token');
  }

  final token = decoded[0];
  if (token is! String || token.isEmpty) {
    throw const FormatException('GenerateIT token was empty');
  }

  final ttl = decoded.length > 1 && decoded[1] is num
      ? (decoded[1] as num).toInt()
      : 3600;

  return (
    integrityTokenLiteral: uint8ArrayLiteral(_decodeBase64(token)),
    ttlSeconds: ttl,
  );
}

/// Encodes [identifier] as a JS `Uint8Array` literal.
String stringToUint8Array(String identifier) =>
    uint8ArrayLiteral(utf8.encode(identifier));

/// Renders [bytes] as `new Uint8Array([1,2,3])`.
String uint8ArrayLiteral(List<int> bytes) =>
    'new Uint8Array([${bytes.join(',')}])';

/// Converts the comma separated byte list a page reports back into the
/// base64url form the player request expects.
String uint8ListToBase64(String commaSeparated) {
  final bytes = <int>[];
  for (final part in commaSeparated.split(',')) {
    final value = int.tryParse(part.trim());
    if (value == null) continue;
    bytes.add(value & 0xff);
  }
  return base64
      .encode(bytes)
      .replaceAll('+', '-')
      .replaceAll('/', '_');
}

/// Base64 with YouTube's URL-safe alphabet and `.` padding.
Uint8List _decodeBase64(String input) {
  final normalised = input
      .replaceAll('-', '+')
      .replaceAll('_', '/')
      .replaceAll('.', '=');
  return base64.decode(normalised);
}

/// Undoes the 97-shift the challenge is scrambled with.
String _descramble(String scrambledChallenge) {
  final bytes = _decodeBase64(scrambledChallenge);
  final decoded = Uint8List(bytes.length);
  for (var i = 0; i < bytes.length; i++) {
    decoded[i] = (bytes[i] + 97) & 0xff;
  }
  return utf8.decode(decoded, allowMalformed: true);
}