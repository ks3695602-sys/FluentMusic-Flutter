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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:musify/theme/glass_config.dart';
import 'package:musify/theme/glass_config_controller.dart';

void main() {
  group('GlassConfig presets', () {
    test('Clear Glass is the refraction-friendly lens', () {
      const config = GlassConfig.clearGlass;
      expect(config.frost, 0.0);
      expect(config.blur, 1.9);
      expect(config.tint, 0.00);
      expect(config.saturation, 1.70);
      expect(config.chromaticAberration, 0.03);
      expect(config.thickness, 60);
      expect(config.refraction, 1.20);
      expect(config.isDefault, isFalse);
    });

    test('Balanced Glass is the shipping default', () {
      const config = GlassConfig.balancedGlass;
      expect(config.frost, 0.4);
      expect(config.blur, 5.7);
      expect(config.tint, 0.00);
      expect(config.saturation, 1.70);
      expect(config.chromaticAberration, 0.03);
      expect(config.thickness, 60);
      expect(config.refraction, 1.20);
      expect(config, GlassConfig.defaults);
      expect(config.isDefault, isTrue);
    });

    test('Frosted Glass prioritizes visibility', () {
      const config = GlassConfig.frostedGlass;
      expect(config.frost, 13.5);
      expect(config.blur, 10.0);
      expect(config.tint, 0.01);
      expect(config.saturation, 1.70);
      expect(config.chromaticAberration, 0.28);
      expect(config.thickness, 60);
      expect(config.refraction, 1.20);
      expect(config.isDefault, isFalse);
    });

    test('a bare GlassConfig starts on Balanced', () {
      expect(const GlassConfig(), GlassConfig.balancedGlass);
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

    test('non-finite values fall back to the Balanced defaults', () {
      final clamped = const GlassConfig(
        frost: double.nan,
        blur: double.infinity,
        saturation: double.negativeInfinity,
      ).clamped();

      expect(clamped.frost, GlassConfig.balancedGlass.frost);
      expect(clamped.blur, GlassConfig.balancedGlass.blur);
      expect(clamped.saturation, GlassConfig.balancedGlass.saturation);
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

    test('missing keys resolve to the Balanced defaults', () {
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

  group('GlassConfigController preset migration', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('fluent_glass_test');
      Hive.init(tempDir.path);
      await Hive.openBox(GlassConfigController.boxName);
    });

    tearDown(() async {
      await Hive.box(GlassConfigController.boxName).clear();
    });

    tearDownAll(() async {
      await Hive.close();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // Windows can hold the box lock for a moment after close.
      }
    });

    Future<GlassConfig> loadFrom(GlassConfig stored) async {
      await Hive.box(GlassConfigController.boxName).put(
        GlassConfigController.storageKey,
        stored.toJson(),
      );
      return GlassConfigController().config;
    }

    test('maps the retired iOS 27 preset to Balanced', () async {
      const legacy = GlassConfig(
        chromaticAberration: 0.12,
        tint: 0.00,
        refraction: 1.35,
        thickness: 56,
        frost: 2,
        blur: 9,
        saturation: 1.6,
      );
      expect(await loadFrom(legacy), GlassConfig.balancedGlass);
      expect(
        Hive.box(GlassConfigController.boxName).get(
          GlassConfigController.schemaKey,
        ),
        GlassConfigController.schemaVersion,
      );
    });

    test('maps the retired Clear Lens preset to Clear Glass', () async {
      const legacy = GlassConfig(
        chromaticAberration: 0.20,
        tint: 0.00,
        refraction: 1.45,
        thickness: 60,
        frost: 0,
        blur: 10,
        saturation: 1.7,
      );
      expect(await loadFrom(legacy), GlassConfig.clearGlass);
    });

    test('maps Soft Frost and Classic to Frosted', () async {
      const softFrost = GlassConfig(
        chromaticAberration: 0.06,
        tint: 0.06,
        refraction: 1.22,
        thickness: 38,
        frost: 12,
        blur: 7,
        saturation: 1.3,
      );
      const classic = GlassConfig(
        chromaticAberration: 0.30,
        tint: 0.24,
        refraction: 1.20,
        thickness: 30,
        frost: 0,
        blur: 3.5,
        saturation: 0.7,
      );

      expect(await loadFrom(softFrost), GlassConfig.frostedGlass);
      await Hive.box(GlassConfigController.boxName).clear();
      expect(await loadFrom(classic), GlassConfig.frostedGlass);
    });

    test('never overwrites a custom tuning', () async {
      final custom = GlassConfig.defaults.copyWith(frost: 4.2, blur: 6.1);
      expect(await loadFrom(custom), custom);
    });
  });
}
