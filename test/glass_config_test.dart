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

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/theme/glass_config.dart';

void main() {
  group('GlassConfig defaults', () {
    test('iOS 27 preset matches the shipped image-2 numbers', () {
      const config = GlassConfig.ios27;
      expect(config.frost, 14);
      expect(config.blur, 4);
      expect(config.tint, 0);
      expect(config.saturation, 1.4);
      expect(config.chromaticAberration, 0);
      expect(config.thickness, 30);
      expect(config.refraction, 1.15);
      expect(config.dynamicTint, isTrue);
      expect(config.barRadius, isNull);
      expect(config.indicatorRadius, isNull);
    });

    test('defaults and ios27 are the same look', () {
      expect(GlassConfig.defaults, GlassConfig.ios27);
      expect(GlassConfig.defaults.isDefault, isTrue);
    });

    test('classic preset keeps the old fringes', () {
      const classic = GlassConfig.classic;
      expect(classic.chromaticAberration, greaterThan(0));
      expect(classic.frost, 0);
      expect(classic.saturation, lessThan(1));
      expect(classic.isDefault, isFalse);
    });
  });

  group('GlassConfig.copyWith', () {
    test('can clear nullable dock and radius overrides', () {
      final tuned = GlassConfig.defaults.copyWith(
        dockTintColor: 0xFF5E5CE6,
        dockTint: 0.4,
        barRadius: 28.0,
      );
      expect(tuned.dockTintColor, 0xFF5E5CE6);
      expect(tuned.dockTint, 0.4);

      final cleared = tuned.copyWith(
        dockTintColor: null,
        dockTint: null,
        barRadius: null,
      );
      expect(cleared.dockTintColor, isNull);
      expect(cleared.dockTint, isNull);
      expect(cleared.barRadius, isNull);
      // Untouched fields survive the clear.
      expect(cleared.frost, tuned.frost);
    });
  });

  group('GlassConfig.clamped', () {
    test('pins out-of-range sliders to their limits', () {
      const wild = GlassConfig(
        frost: 99,
        blur: -3,
        tint: 8,
        saturation: 12,
        chromaticAberration: -1,
        thickness: 900,
        refraction: 4,
        pinchStrength: 2,
      );
      final clamped = wild.clamped();

      expect(clamped.frost, GlassConfig.frostMax);
      expect(clamped.blur, GlassConfig.blurMin);
      expect(clamped.tint, GlassConfig.tintMax);
      expect(clamped.saturation, GlassConfig.saturationMax);
      expect(clamped.chromaticAberration, GlassConfig.chromaticAberrationMin);
      expect(clamped.thickness, GlassConfig.thicknessMax);
      expect(clamped.refraction, GlassConfig.refractionMax);
      expect(clamped.pinchStrength, GlassConfig.pinchStrengthMax);
    });

    test('non-finite values fall back to defaults', () {
      final clamped = const GlassConfig(
        frost: double.nan,
        blur: double.infinity,
        saturation: double.negativeInfinity,
      ).clamped();

      expect(clamped.frost, GlassConfig.defaults.frost);
      expect(clamped.blur, GlassConfig.defaults.blur);
      expect(clamped.saturation, GlassConfig.defaults.saturation);
    });
  });

  group('GlassConfig JSON', () {
    test('round-trips every field including dock overrides', () {
      final tuned = GlassConfig.defaults.copyWith(
        frost: 9.5,
        blur: 6,
        saturation: 2,
        tintColor: 0xFF0A84FF,
        dockTintColor: 0xFFFF9F0A,
        dockTint: 0.32,
        dynamicTint: false,
        barRadius: 24.0,
        indicatorRadius: 14.0,
      );

      final decoded = GlassConfig.fromJson(tuned.toJson());
      expect(decoded, tuned);
      expect(GlassConfig.fromJsonString(tuned.toJsonString()), tuned);
    });

    test('missing keys resolve to the iOS 27 defaults', () {
      final decoded = GlassConfig.fromJson(const <String, dynamic>{});
      expect(decoded, GlassConfig.defaults);
    });

    test('junk JSON is rejected loudly', () {
      expect(
        () => GlassConfig.fromJsonString('[1, 2, 3]'),
        throwsFormatException,
      );
    });
  });
}
