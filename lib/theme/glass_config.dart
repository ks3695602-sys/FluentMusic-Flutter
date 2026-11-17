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
  /// Creates a glass configuration seeded with the Balanced preset values.
  ///
  /// These constructor defaults are the app's shipping look, so a config
  /// decoded without a full field set can never fall back to a preset that no
  /// longer exists.
  const GlassConfig({
    this.pinchStrength = 0.40,
    this.expansionH = 12,
    this.expansionV = 8,
    this.chromaticAberration = 0.03,
    this.tint = 0.00,
    this.refraction = 1.20,
    this.thickness = 60.0,
    this.frost = 0.4,
    this.blur = 5.7,
    this.saturation = 1.7,
    this.tintColor = 0xFFFFFFFF,
    this.dockTintColor,
    this.dockTint,
    this.dynamicTint = true,
    this.barRadius,
    this.indicatorRadius,
  });

  /// Clear Glass: zero frost, the shallowest blur and a razor-clear lens.
  /// Best on dark, artwork-heavy pages where the backdrop should stay legible.
  static const GlassConfig clearGlass = GlassConfig(
    chromaticAberration: 0.03,
    tint: 0.00,
    refraction: 1.20,
    thickness: 60,
    frost: 0.0,
    blur: 1.9,
    saturation: 1.7,
  );

  /// Balanced Glass (Default): a little frost and blur for legibility without
  /// losing the refraction that makes the dock read as a lens.
  static const GlassConfig balancedGlass = GlassConfig();

  /// Frosted: maximum visibility on bright or busy artwork. The heavier frost,
  /// stronger fringe and full blur make labels readable first, glassy second.
  static const GlassConfig frostedGlass = GlassConfig(
    chromaticAberration: 0.28,
    tint: 0.01,
    refraction: 1.20,
    thickness: 60,
    frost: 13.5,
    blur: 10.0,
    saturation: 1.7,
  );

  /// Shipping default. Balanced wins on real devices: readable over pale
  /// artwork while keeping the lens visible.
  static const GlassConfig defaults = balancedGlass;

  /// Minimum/maximum accepted values (also used by the Lab sliders).
  static const double pinchStrengthMin = 0.0;
  static const double pinchStrengthMax = 1.0;
  static const double expansionMin = 0.0;
  static const double expansionMax = 32.0;
  static const double chromaticAberrationMin = 0.0;
  static const double chromaticAberrationMax = 0.5;
  static const double tintMin = 0.0;
  static const double tintMax = 0.8;
  static const double refractionMin = 1.0;
  static const double refractionMax = 1.5;
  static const double thicknessMin = 0.0;
  static const double thicknessMax = 60.0;
  static const double frostMin = 0.0;
  static const double frostMax = 20.0;
  static const double blurMin = 0.0;
  static const double blurMax = 10.0;
  static const double saturationMin = 0.5;
  static const double saturationMax = 2.5;
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

  /// Refractive index (`LiquidGlassSettings.refractiveIndex`), i.e. how much
  /// the glass bends the content behind it.
  final double refraction;

  /// Refraction height in logical pixels (`LiquidGlassSettings.thickness`).
  /// Higher values make the lens feel deeper.
  final double thickness;

  /// Frost cloud amount (`LiquidGlassSettings.frost`). This is the wide,
  /// milky diffusion stage that sits on top of the backdrop blur.
  final double frost;

  /// Backdrop Gaussian sigma (`LiquidGlassSettings.blur`).
  final double blur;

  /// Colour intensity of the backdrop (`LiquidGlassSettings.saturation`).
  final double saturation;

  /// Base tint colour as `0xAARRGGBB`. Its alpha comes from [tint], so the
  /// same colour works in light and dark.
  final int tintColor;

  /// Optional dock-only tint colour. `null` inherits [tintColor].
  final int? dockTintColor;

  /// Optional dock-only tint alpha. `null` inherits [tint].
  final double? dockTint;

  /// When true the glass picks up the backdrop's colour. When false it uses
  /// the fixed [tintColor] at [tint], saturation 1.0 and no adaptive
  /// brightness.
  final bool dynamicTint;

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
    double? thickness,
    double? frost,
    double? blur,
    double? saturation,
    int? tintColor,
    Object? dockTintColor = _unset,
    Object? dockTint = _unset,
    bool? dynamicTint,
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
      thickness: thickness ?? this.thickness,
      frost: frost ?? this.frost,
      blur: blur ?? this.blur,
      saturation: saturation ?? this.saturation,
      tintColor: tintColor ?? this.tintColor,
      dockTintColor: identical(dockTintColor, _unset)
          ? this.dockTintColor
          : dockTintColor as int?,
      dockTint: identical(dockTint, _unset)
          ? this.dockTint
          : dockTint as double?,
      dynamicTint: dynamicTint ?? this.dynamicTint,
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
      thickness: _clamp(
        thickness,
        thicknessMin,
        thicknessMax,
        defaults.thickness,
      ),
      frost: _clamp(frost, frostMin, frostMax, defaults.frost),
      blur: _clamp(blur, blurMin, blurMax, defaults.blur),
      saturation: _clamp(
        saturation,
        saturationMin,
        saturationMax,
        defaults.saturation,
      ),
      tintColor: tintColor,
      dockTintColor: dockTintColor,
      dockTint: dockTint == null
          ? null
          : _clamp(dockTint!, tintMin, tintMax, defaults.tint),
      dynamicTint: dynamicTint,
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
      'thickness': thickness,
      'frost': frost,
      'blur': blur,
      'saturation': saturation,
      'tintColor': tintColor,
      'dockTintColor': dockTintColor,
      'dockTint': dockTint,
      'dynamicTint': dynamicTint,
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
      thickness: _readDouble(json['thickness'], defaults.thickness),
      frost: _readDouble(json['frost'], defaults.frost),
      blur: _readDouble(json['blur'], defaults.blur),
      saturation: _readDouble(json['saturation'], defaults.saturation),
      tintColor: _readColor(json['tintColor'], defaults.tintColor),
      dockTintColor: _readNullableColor(json['dockTintColor']),
      dockTint: _readNullableDouble(json['dockTint']),
      dynamicTint: json['dynamicTint'] is bool
          ? json['dynamicTint'] as bool
          : defaults.dynamicTint,
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

  static int _readColor(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.replaceFirst('#', ''));
      if (parsed != null) {
        return parsed <= 0xFFFFFF ? 0xFF000000 | parsed : parsed;
      }
    }
    return fallback;
  }

  static int? _readNullableColor(Object? value) {
    if (value == null) return null;
    final parsed = _readColor(value, -1);
    return parsed == -1 ? null : parsed;
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
            other.thickness == thickness &&
            other.frost == frost &&
            other.blur == blur &&
            other.saturation == saturation &&
            other.tintColor == tintColor &&
            other.dockTintColor == dockTintColor &&
            other.dockTint == dockTint &&
            other.dynamicTint == dynamicTint &&
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
        thickness,
        frost,
        blur,
        saturation,
        tintColor,
        dockTintColor,
        dockTint,
        dynamicTint,
        barRadius,
        indicatorRadius,
      );

  @override
  String toString() {
    return 'GlassConfig(pinch: $pinchStrength, expansion: '
        '$expansionH x $expansionV, aberration: $chromaticAberration, '
        'tint: $tint, refraction: $refraction, thickness: $thickness, '
        'frost: $frost, blur: $blur, saturation: $saturation, '
        'tintColor: $tintColor, dockTintColor: $dockTintColor, '
        'dockTint: $dockTint, dynamicTint: $dynamicTint, '
        'barRadius: $barRadius, '
        'indicatorRadius: $indicatorRadius)';
  }
}
