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

import 'package:flutter/foundation.dart';

/// One rung of the streaming ladder, as it was actually tried.
class StreamAttempt {
  StreamAttempt({
    required this.songId,
    required this.client,
    required this.ok,
    required this.latencyMs,
    this.reason,
    this.usedTokens = false,
    this.probeBytes = 0,
  }) : at = DateTime.now();

  final DateTime at;
  final String songId;
  final String client;
  final bool ok;
  final int latencyMs;
  final String? reason;

  /// Whether the client asked with a BotGuard token.
  final bool usedTokens;

  /// Where the first-bytes probe read from, so a 1 MiB-boundary refusal is
  /// visible instead of guessed at.
  final int probeBytes;

  String get summary {
    final outcome = ok ? 'OK' : 'failed';
    final token = usedTokens ? ' · token' : '';
    final probe = probeBytes > 0 ? ' · probe @$probeBytes' : '';
    return '${client.padRight(18)} $outcome '
        '${latencyMs}ms$token$probe';
  }
}

/// The most recent attempts, newest first.
final streamDiagnostics = ValueNotifier<List<StreamAttempt>>(const []);

const _maxEntries = 80;

void recordStreamAttempt(StreamAttempt attempt) {
  final next = [attempt, ...streamDiagnostics.value];
  if (next.length > _maxEntries) next.removeRange(_maxEntries, next.length);
  streamDiagnostics.value = List.unmodifiable(next);
}

void clearStreamDiagnostics() {
  streamDiagnostics.value = const [];
}