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

/// Bridge between the inline search field inside the bottom bar and the
/// Explore tab that renders its results.
///
/// The bar owns its own TextField (it lives in the tab bar), while Explore owns
/// the result state. This tiny hand-off keeps both in sync without a global
/// router dependency:
///
/// 1. Bar submits a query → [submit] stores it as pending.
/// 2. Explore listens to [request]; on every tick it calls [takePending].
/// 3. If Explore was not built yet (cold branch), the pending query stays
///    queued and is consumed on first frame.
/// 4. Dismissing the bar calls [requestClear], which puts Explore back on its
///    discovery feed.
class InlineSearchBridge {
  InlineSearchBridge._();

  /// Bumped once per submitted query. Listeners read from [takePending].
  static final ValueNotifier<int> request = ValueNotifier<int>(0);

  /// Bumped when the bar closes so Explore can drop the old results.
  static final ValueNotifier<int> clearRequest = ValueNotifier<int>(0);

  /// Whether the dock's inline search field is currently expanded.
  ///
  /// Explore uses this to show a recent-search landing instead of the feed
  /// while the user is typing, so the first keystroke never lands on top of a
  /// fully loaded discovery page.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// Updates [active] without notifying when the value is unchanged.
  static void setActive(bool value) {
    if (active.value == value) return;
    active.value = value;
  }

  static String? _pendingQuery;
  static String _lastQuery = '';
  static bool _pendingClear = false;

  /// Bumped when a page wants the dock to leave its searchable state, e.g.
  /// "Back to Explore" inside the results page.
  static final ValueNotifier<int> collapseRequest = ValueNotifier<int>(0);

  /// Last query that was submitted through the bar (handy for "recent search").
  static String get lastQuery => _lastQuery;

  /// Queues a clear request and notifies Explore. If the page is cold, it
  /// consumes the request on its first frame.
  static void requestClear() {
    _pendingClear = true;
    clearRequest.value++;
  }

  /// Asks the dock to collapse its inline search field.
  static void requestCollapse() {
    collapseRequest.value++;
  }

  /// Returns whether a clear request is queued, and clears it.
  static bool takeClearRequest() {
    final pending = _pendingClear;
    _pendingClear = false;
    return pending;
  }

  /// Queues [query] and notifies Explore. Empty queries are ignored.
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
