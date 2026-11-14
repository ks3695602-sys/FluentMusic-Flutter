/*
 *     Copyright (C) 2026 jaypakash sahu
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
 *     FluentMusic by jaypakash sahu
 *     https://github.com/ks3695602-sys/FluentMusic-Flutter
 */

import 'package:flutter/foundation.dart';

/// Bridge between the inline search field inside the bottom bar and the real
/// [SearchPage].
///
/// The bar owns its own TextField (it lives in the tab bar), while the search
/// results page owns its own controller. This tiny hand-off keeps both in sync
/// without a global router dependency:
///
/// 1. Bar submits a query → [submit] stores it as pending.
/// 2. SearchPage listens to [request]; on every tick it calls [takePending].
/// 3. If SearchPage was not built yet (cold branch), the pending query stays
///    queued and is consumed on first frame.
class InlineSearchBridge {
  InlineSearchBridge._();

  /// Bumped once per submitted query. Listeners read from [takePending].
  static final ValueNotifier<int> request = ValueNotifier<int>(0);

  static String? _pendingQuery;
  static String _lastQuery = '';

  /// Last query that was submitted through the bar (handy for "recent search").
  static String get lastQuery => _lastQuery;

  /// Queues [query] and notifies the search page. Empty queries are ignored.
  static void submit(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _pendingQuery = trimmed;
    _lastQuery = trimmed;
    request.value++;
  }

  /// Returns the queued query once and clears it.
  static String? takePending() {
    final pending = _pendingQuery;
    _pendingQuery = null;
    return pending;
  }
}
