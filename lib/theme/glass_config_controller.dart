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

  /// Hive key recording which preset vocabulary the saved config uses.
  ///
  /// Version 1 is the retired iOS 27 / Clear Lens / Soft Frost / Classic set;
  /// version 2 is Clear Glass / Balanced Glass / Frosted.
  static const String schemaKey = 'glassConfigSchema';
  static const int schemaVersion = 2;

  /// Retired built-in presets. Kept privately so an upgrade can move a stored
  /// built-in look onto its closest replacement without resurrecting the old
  /// names in the Lab.
  static const GlassConfig _legacyIos27 = GlassConfig(
    chromaticAberration: 0.12,
    tint: 0.00,
    refraction: 1.35,
    thickness: 56,
    frost: 2,
    blur: 9,
    saturation: 1.6,
  );
  static const GlassConfig _legacyClearLens = GlassConfig(
    chromaticAberration: 0.20,
    tint: 0.00,
    refraction: 1.45,
    thickness: 60,
    frost: 0,
    blur: 10,
    saturation: 1.7,
  );
  static const GlassConfig _legacySoftFrost = GlassConfig(
    chromaticAberration: 0.06,
    tint: 0.06,
    refraction: 1.22,
    thickness: 38,
    frost: 12,
    blur: 7,
    saturation: 1.3,
  );
  static const GlassConfig _legacyClassic = GlassConfig(
    chromaticAberration: 0.30,
    tint: 0.24,
    refraction: 1.20,
    thickness: 30,
    frost: 0,
    blur: 3.5,
    saturation: 0.7,
  );

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

  /// Distortion amount (`LiquidGlassSettings.refractiveIndex`).
  void setRefraction(double value) =>
      update(_config.copyWith(refraction: value));

  /// Alias used by the Lab label "Distortion amount".
  void setDistortionAmount(double value) => setRefraction(value);

  /// Refraction height (`LiquidGlassSettings.thickness`).
  void setThickness(double value) =>
      update(_config.copyWith(thickness: value));

  /// Frost cloud amount (`LiquidGlassSettings.frost`).
  void setFrost(double value) => update(_config.copyWith(frost: value));

  /// Backdrop blur sigma (`LiquidGlassSettings.blur`).
  void setBlur(double value) => update(_config.copyWith(blur: value));

  /// Backdrop colour intensity (`LiquidGlassSettings.saturation`).
  void setSaturation(double value) =>
      update(_config.copyWith(saturation: value));

  /// Base tint colour, stored as `0xAARRGGBB`.
  void setTintColor(int value) =>
      update(_config.copyWith(tintColor: value));

  /// Dock-only tint colour. Pass `null` to inherit the global colour.
  void setDockTintColor(int? value) =>
      update(_config.copyWith(dockTintColor: value));

  /// Dock-only tint alpha. Pass `null` to inherit the global alpha.
  void setDockTint(double? value) =>
      update(_config.copyWith(dockTint: value));

  /// Turns backdrop-driven tinting on or off.
  void setDynamicTint(bool value) =>
      update(_config.copyWith(dynamicTint: value));

  /// Applies the Clear Glass (Refraction Friendly) preset.
  void applyClearGlass() => update(GlassConfig.clearGlass);

  /// Applies the Balanced Glass (Default) preset.
  void applyBalancedGlass() => update(GlassConfig.balancedGlass);

  /// Applies the Frosted (Visibility at Its Peak) preset.
  void applyFrostedGlass() => update(GlassConfig.frostedGlass);

  /// Pass `null` to restore the package capsule radius.
  void setBarRadius(double? value) =>
      update(_config.copyWith(barRadius: value));

  /// Pass `null` to restore the package automatic radius.
  void setIndicatorRadius(double? value) =>
      update(_config.copyWith(indicatorRadius: value));

  /// Restores the Balanced Glass (Default) preset.
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
      final box = Hive.box(boxName);
      final storedSchema = box.get(schemaKey);
      var needsWrite = false;

      final stored = box.get(storageKey);
      if (stored is Map) {
        _config = GlassConfig.fromJson(stored);
      } else if (stored is String) {
        _config = GlassConfig.fromJsonString(stored);
      }

      // Only migrate configurations written by the retired preset set. A
      // custom tuning survives untouched, which is why this is gated on the
      // schema key instead of comparing every load.
      if (storedSchema is! int || storedSchema < schemaVersion) {
        final migrated = _migrateLegacyPreset(_config);
        if (migrated != _config) {
          _config = migrated;
          needsWrite = true;
        }
        unawaited(box.put(schemaKey, schemaVersion));
      }

      if (needsWrite) unawaited(_persist());
    } catch (error, stackTrace) {
      debugPrint('GlassConfigController: failed to load config: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Maps a retired built-in look onto its closest new preset.
  static GlassConfig _migrateLegacyPreset(GlassConfig config) {
    if (config == _legacyIos27) return GlassConfig.balancedGlass;
    if (config == _legacyClearLens) return GlassConfig.clearGlass;
    if (config == _legacySoftFrost || config == _legacyClassic) {
      return GlassConfig.frostedGlass;
    }
    return config;
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
