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

// Pure Dart model for the Glass Lab tuner. Keep this file free of Flutter
// imports so it can be unit tested and imported without a widget tree.
//
// Slider -> package mapping lives in docs/GLASS_API.md (section 8).

import 'dart:convert';

/// Sentinel used by [GlassConfig.copyWith] so `null` can be passed on purpose
/// for the nullable radius fields.
const Object _unset = Object();

/// Live tunable liquid-glass parameters for FluentMusic.
///
/// Every value is persisted as-is and read back by the Glass Lab. Validation
/// happens in [clamped] so a malformed import can never push the shader into
/// an invalid state.
class GlassConfig {
  /// Creates a glass configuration.
  const GlassConfig({
    this.pinchStrength = 0.40,
    this.expansionH = 12,
    this.expansionV = 8,
    this.chromaticAberration = 0.15,
    this.tint = 0.00,
    this.refraction = 1.15,
    this.barRadius,
    this.indicatorRadius,
  });

  /// iOS 27 calibrated defaults. `null` radius means "let the package decide"
  /// (capsule bar, automatic indicator radius).
  static const GlassConfig defaults = GlassConfig();

  /// Minimum/maximum accepted values (also used by the Lab sliders).
  static const double pinchStrengthMin = 0.0;
  static const double pinchStrengthMax = 1.0;
  static const double expansionMin = 0.0;
  static const double expansionMax = 32.0;
  static const double chromaticAberrationMin = 0.0;
  static const double chromaticAberrationMax = 0.5;
  static const double tintMin = 0.0;
  static const double tintMax = 1.0;
  static const double refractionMin = 1.0;
  static const double refractionMax = 1.5;
  static const double radiusMin = 0.0;
  static const double radiusMax = 60.0;

  /// Indicator pinch strength (`GlassTabBar.indicatorPinchStrength`).
  final double pinchStrength;

  /// Horizontal indicator expansion in logical pixels.
  final double expansionH;

  /// Vertical indicator expansion in logical pixels.
  final double expansionV;

  /// Chromatic dispersion strength (`LiquidGlassSettings.chromaticAberration`).
  final double chromaticAberration;

  /// Alpha of the glass tint (`LiquidGlassSettings.glassColor` alpha).
  /// 0 = perfectly clear, 1 = fully tinted.
  final double tint;

  /// Refractive index (`LiquidGlassSettings.refractiveIndex`).
  final double refraction;

  /// Bar corner radius. `null` = package capsule.
  final double? barRadius;

  /// Selection indicator corner radius. `null` = package automatic radius.
  final double? indicatorRadius;

  /// True when every value equals [defaults].
  bool get isDefault => this == defaults;

  /// Returns a copy with the given fields replaced.
  ///
  /// Pass `barRadius: null` / `indicatorRadius: null` explicitly to clear them.
  GlassConfig copyWith({
    double? pinchStrength,
    double? expansionH,
    double? expansionV,
    double? chromaticAberration,
    double? tint,
    double? refraction,
    Object? barRadius = _unset,
    Object? indicatorRadius = _unset,
  }) {
    return GlassConfig(
      pinchStrength: pinchStrength ?? this.pinchStrength,
      expansionH: expansionH ?? this.expansionH,
      expansionV: expansionV ?? this.expansionV,
      chromaticAberration: chromaticAberration ?? this.chromaticAberration,
      tint: tint ?? this.tint,
      refraction: refraction ?? this.refraction,
      barRadius: identical(barRadius, _unset)
          ? this.barRadius
          : barRadius as double?,
      indicatorRadius: identical(indicatorRadius, _unset)
          ? this.indicatorRadius
          : indicatorRadius as double?,
    );
  }

  /// Returns a copy with every field forced into its supported range.
  ///
  /// Non-finite values fall back to the corresponding default.
  GlassConfig clamped() {
    return GlassConfig(
      pinchStrength: _clamp(
        pinchStrength,
        pinchStrengthMin,
        pinchStrengthMax,
        defaults.pinchStrength,
      ),
      expansionH: _clamp(
        expansionH,
        expansionMin,
        expansionMax,
        defaults.expansionH,
      ),
      expansionV: _clamp(
        expansionV,
        expansionMin,
        expansionMax,
        defaults.expansionV,
      ),
      chromaticAberration: _clamp(
        chromaticAberration,
        chromaticAberrationMin,
        chromaticAberrationMax,
        defaults.chromaticAberration,
      ),
      tint: _clamp(tint, tintMin, tintMax, defaults.tint),
      refraction: _clamp(
        refraction,
        refractionMin,
        refractionMax,
        defaults.refraction,
      ),
      barRadius: barRadius == null
          ? null
          : _clamp(barRadius!, radiusMin, radiusMax, 0),
      indicatorRadius: indicatorRadius == null
          ? null
          : _clamp(indicatorRadius!, radiusMin, radiusMax, 0),
    );
  }

  /// JSON-friendly representation (safe for Hive and file export).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pinchStrength': pinchStrength,
      'expansionH': expansionH,
      'expansionV': expansionV,
      'chromaticAberration': chromaticAberration,
      'tint': tint,
      'refraction': refraction,
      'barRadius': barRadius,
      'indicatorRadius': indicatorRadius,
    };
  }

  /// Builds a config from a decoded JSON map, clamping invalid values.
  factory GlassConfig.fromJson(Map<dynamic, dynamic> json) {
    return GlassConfig(
      pinchStrength: _readDouble(
        json['pinchStrength'],
        defaults.pinchStrength,
      ),
      expansionH: _readDouble(json['expansionH'], defaults.expansionH),
      expansionV: _readDouble(json['expansionV'], defaults.expansionV),
      chromaticAberration: _readDouble(
        json['chromaticAberration'],
        defaults.chromaticAberration,
      ),
      tint: _readDouble(json['tint'], defaults.tint),
      refraction: _readDouble(json['refraction'], defaults.refraction),
      barRadius: _readNullableDouble(json['barRadius']),
      indicatorRadius: _readNullableDouble(json['indicatorRadius']),
    ).clamped();
  }

  /// Encodes this config as a single JSON string (Lab export / clipboard).
  String toJsonString() => jsonEncode(toJson());

  /// Decodes a config from a JSON string. Throws [FormatException] on junk.
  factory GlassConfig.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) {
      throw const FormatException('GlassConfig JSON must be an object');
    }
    return GlassConfig.fromJson(decoded);
  }

  static double _readDouble(Object? value, double fallback) {
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : fallback;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return fallback;
  }

  static double? _readNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) {
      final parsed = value.toDouble();
      return parsed.isFinite ? parsed : null;
    }
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  static double _clamp(double value, double min, double max, double fallback) {
    if (!value.isFinite) return fallback;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is GlassConfig &&
            other.pinchStrength == pinchStrength &&
            other.expansionH == expansionH &&
            other.expansionV == expansionV &&
            other.chromaticAberration == chromaticAberration &&
            other.tint == tint &&
            other.refraction == refraction &&
            other.barRadius == barRadius &&
            other.indicatorRadius == indicatorRadius;
  }

  @override
  int get hashCode => Object.hash(
        pinchStrength,
        expansionH,
        expansionV,
        chromaticAberration,
        tint,
        refraction,
        barRadius,
        indicatorRadius,
      );

  @override
  String toString() {
    return 'GlassConfig(pinch: $pinchStrength, expansion: '
        '$expansionH x $expansionV, aberration: $chromaticAberration, '
        'tint: $tint, refraction: $refraction, barRadius: $barRadius, '
        'indicatorRadius: $indicatorRadius)';
  }
}
