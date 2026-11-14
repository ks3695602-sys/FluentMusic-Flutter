/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:musify/theme/glass_config.dart';

/// Owns the live [GlassConfig] and keeps it in sync with Hive.
///
/// Storage lives in the existing `settings` box (same box used by
/// `settings_manager.dart`) so no migration is needed. Values are stored as a
/// plain JSON map under [_storageKey].
class GlassConfigController extends ChangeNotifier {
  /// Creates a controller, optionally seeded with an [initial] config.
  GlassConfigController({GlassConfig? initial})
      : _config = (initial ?? GlassConfig.defaults).clamped();

  /// Hive box shared with the rest of the app settings.
  static const String boxName = 'settings';

  /// Hive key holding the exported JSON map.
  static const String storageKey = 'glassConfig';

  GlassConfig _config;
  bool _loaded = false;

  /// Current configuration. Triggers a lazy Hive read on first access.
  GlassConfig get config {
    _ensureLoaded();
    return _config;
  }

  /// True once Hive has been consulted (or there was no box to consult).
  bool get isLoaded => _loaded;

  /// Applies [next] (clamped), notifies listeners and persists if changed.
  void update(GlassConfig next) {
    _ensureLoaded();
    final clamped = next.clamped();
    if (clamped == _config) return;
    _config = clamped;
    notifyListeners();
    unawaited(_persist());
  }

  void setPinchStrength(double value) =>
      update(_config.copyWith(pinchStrength: value));

  void setExpansionH(double value) =>
      update(_config.copyWith(expansionH: value));

  void setExpansionV(double value) =>
      update(_config.copyWith(expansionV: value));

  void setChromaticAberration(double value) =>
      update(_config.copyWith(chromaticAberration: value));

  void setTint(double value) => update(_config.copyWith(tint: value));

  void setRefraction(double value) =>
      update(_config.copyWith(refraction: value));

  /// Pass `null` to restore the package capsule radius.
  void setBarRadius(double? value) =>
      update(_config.copyWith(barRadius: value));

  /// Pass `null` to restore the package automatic radius.
  void setIndicatorRadius(double? value) =>
      update(_config.copyWith(indicatorRadius: value));

  /// Restores the iOS 27 calibrated defaults.
  void reset() => update(GlassConfig.defaults);

  /// Pretty JSON for the Lab "copy" action.
  String exportJson() {
    _ensureLoaded();
    return _config.toJsonString();
  }

  /// Imports a JSON string. Returns `false` for malformed input; the current
  /// config is left untouched in that case.
  bool importJson(String source) {
    try {
      update(GlassConfig.fromJsonString(source));
      return true;
    } on FormatException {
      return false;
    }
  }

  /// Re-reads the persisted config (e.g. after a backup restore).
  void reloadFromStorage() {
    _loaded = false;
    _ensureLoaded();
    notifyListeners();
  }

  void _ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    try {
      if (!Hive.isBoxOpen(boxName)) return;
      final stored = Hive.box(boxName).get(storageKey);
      if (stored is Map) {
        _config = GlassConfig.fromJson(stored);
      } else if (stored is String) {
        _config = GlassConfig.fromJsonString(stored);
      }
    } catch (error, stackTrace) {
      debugPrint('GlassConfigController: failed to load config: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> _persist() async {
    if (!Hive.isBoxOpen(boxName)) return;
    try {
      await Hive.box(boxName).put(storageKey, _config.toJson());
    } catch (error, stackTrace) {
      debugPrint('GlassConfigController: failed to persist config: $error');
      debugPrint('$stackTrace');
    }
  }
}

/// App-wide controller instance. Lazy, so it is safe to import before Hive is
/// initialized.
final GlassConfigController glassConfigController = GlassConfigController();

/// Exposes the [GlassConfigController] to the widget tree.
///
/// Descendants that call [of] rebuild whenever the tuner changes a value.
class GlassConfigScope extends InheritedNotifier<GlassConfigController> {
  /// Creates a scope around [child] using [controller].
  const GlassConfigScope({
    required GlassConfigController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Returns the controller and subscribes to its changes.
  static GlassConfigController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<GlassConfigScope>();
    assert(scope != null, 'GlassConfigScope.of() called outside a scope');
    return scope!.notifier!;
  }

  /// Returns the controller if a scope is present, without asserting.
  static GlassConfigController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GlassConfigScope>()
        ?.notifier;
  }
}
