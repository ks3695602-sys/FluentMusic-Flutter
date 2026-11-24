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

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Theme;
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/theme/glass_config.dart';
import 'package:musify/theme/glass_config_controller.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/glass/glass_backdrop.dart';
import 'package:musify/widgets/glass/glass_sheet_style.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';

/// Live tuner for the liquid-glass engine.
///
/// Eight sliders, each wired straight to [GlassConfigController]. Changes are
/// persisted to Hive and pushed into the global glass theme immediately, so the
/// preview and the rest of the app update while dragging.
class GlassLabPage extends StatelessWidget {
  /// Creates the Glass Lab page.
  const GlassLabPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = GlassConfigScope.of(context);
    final config = controller.config;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassScaffold(
      extendBody: false,
      contentAwareBrightness: true,
      background: const GlassBackdrop(animate: false),
      appBar: GlassAppBar(
        leading: _buildBackButton(context),
        title: Text(
          'Glass Lab',
          style: TextStyle(fontWeight: FontWeight.bold, color: titleColor),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildPreview(context, config),
          const SizedBox(height: 16),
          GlassGroupedSection(
            header: _sectionHeader('PRESET', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.drop_fill,
                  color: Color(0xFF30D158),
                ),
                title: Text(
                  'Clear Glass',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Refraction Friendly · zero frost, razor-clear lens',
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
                trailing: config == GlassConfig.clearGlass
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF30D158),
                      )
                    : null,
                onTap: () {
                  controller.applyClearGlass();
                  showToast(context, 'Clear Glass applied 💧');
                },
              ),
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.sparkles,
                  color: Color(0xFF0A84FF),
                ),
                title: Text(
                  'Balanced Glass',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Default · soft frost, balanced clarity',
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
                trailing: config == GlassConfig.balancedGlass
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFF0A84FF),
                      )
                    : null,
                onTap: () {
                  controller.applyBalancedGlass();
                  showToast(context, 'Balanced Glass applied ✨');
                },
              ),
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.cloud_fill,
                  color: Color(0xFFFF9F0A),
                ),
                title: Text(
                  'Frosted',
                  style: TextStyle(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Visibility at Its Peak · maximum legibility',
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
                trailing: config == GlassConfig.frostedGlass
                    ? const Icon(
                        CupertinoIcons.checkmark_circle_fill,
                        color: Color(0xFFFF9F0A),
                      )
                    : null,
                onTap: () {
                  controller.applyFrostedGlass();
                  showToast(context, 'Frosted Glass applied ☁️');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('INDICATOR PARITY', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              _LabSliderTile(
                icon: CupertinoIcons.slider_horizontal_3,
                color: const Color(0xFF0A84FF),
                title: 'Pinch strength',
                valueLabel: config.pinchStrength.toStringAsFixed(2),
                value: config.pinchStrength,
                min: GlassConfig.pinchStrengthMin,
                max: GlassConfig.pinchStrengthMax,
                onChanged: controller.setPinchStrength,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.slider_horizontal_below_rectangle,
                color: const Color(0xFF30D158),
                title: 'Expansion H',
                valueLabel: '${config.expansionH.round()} px',
                value: config.expansionH,
                min: GlassConfig.expansionMin,
                max: GlassConfig.expansionMax,
                onChanged: controller.setExpansionH,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.arrow_down_to_line,
                color: const Color(0xFF30D158),
                title: 'Expansion V',
                valueLabel: '${config.expansionV.round()} px',
                value: config.expansionV,
                min: GlassConfig.expansionMin,
                max: GlassConfig.expansionMax,
                onChanged: controller.setExpansionV,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('OPTICS', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              _LabSliderTile(
                icon: CupertinoIcons.cloud,
                color: const Color(0xFF64D2FF),
                title: 'Frost',
                valueLabel: config.frost.toStringAsFixed(1),
                value: config.frost,
                min: GlassConfig.frostMin,
                max: GlassConfig.frostMax,
                onChanged: controller.setFrost,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.slider_horizontal_3,
                color: const Color(0xFF30D158),
                title: 'Blur sigma',
                valueLabel: config.blur.toStringAsFixed(1),
                value: config.blur,
                min: GlassConfig.blurMin,
                max: GlassConfig.blurMax,
                onChanged: controller.setBlur,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.drop,
                color: const Color(0xFF007AFF),
                title: 'Tint alpha',
                valueLabel: config.tint.toStringAsFixed(2),
                value: config.tint,
                min: GlassConfig.tintMin,
                max: GlassConfig.tintMax,
                onChanged: controller.setTint,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.paintbrush,
                color: const Color(0xFFFF375F),
                title: 'Saturation',
                valueLabel: config.saturation.toStringAsFixed(2),
                value: config.saturation,
                min: GlassConfig.saturationMin,
                max: GlassConfig.saturationMax,
                onChanged: controller.setSaturation,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.wand_stars,
                color: const Color(0xFFAF52DE),
                title: 'Chromatic aberration',
                valueLabel: config.chromaticAberration.toStringAsFixed(2),
                value: config.chromaticAberration,
                min: GlassConfig.chromaticAberrationMin,
                max: GlassConfig.chromaticAberrationMax,
                onChanged: controller.setChromaticAberration,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.arrow_up_down,
                color: const Color(0xFFFF9500),
                title: 'Thickness',
                valueLabel: '${config.thickness.round()} px',
                value: config.thickness,
                min: GlassConfig.thicknessMin,
                max: GlassConfig.thicknessMax,
                onChanged: controller.setThickness,
              ),
              _LabSliderTile(
                icon: CupertinoIcons.waveform,
                color: const Color(0xFF5856D6),
                title: 'Refractive index',
                valueLabel: config.refraction.toStringAsFixed(2),
                value: config.refraction,
                min: GlassConfig.refractionMin,
                max: GlassConfig.refractionMax,
                onChanged: controller.setDistortionAmount,
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('COLOR & TRANSPARENCY', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              _buildColorTile(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                title: 'Glass colour',
                subtitle:
                    'Global tint used by cards, sheets and the dock by default',
                color: Color(config.tintColor),
                onTap: () => _pickColor(context, controller, dock: false),
              ),
              _buildColorTile(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                title: 'Dock colour',
                subtitle: config.dockTintColor == null
                    ? 'Following the global glass colour'
                    : 'Custom colour, independent of everything else',
                color: Color(config.dockTintColor ?? config.tintColor),
                inherited: config.dockTintColor == null,
                onTap: () => _pickColor(context, controller, dock: true),
              ),
              _LabSliderTile(
                icon: CupertinoIcons.drop_fill,
                color: const Color(0xFF0A84FF),
                title: 'Dock transparency',
                valueLabel: (config.dockTint ?? config.tint).toStringAsFixed(2),
                value: config.dockTint ?? config.tint,
                min: GlassConfig.tintMin,
                max: GlassConfig.tintMax,
                onChanged: controller.setDockTint,
              ),
              GlassListTile(
                leading: const Icon(
                  CupertinoIcons.circle_lefthalf_fill,
                  color: Color(0xFFBF5AF2),
                ),
                title: Text(
                  'Dynamic background tint',
                  style: TextStyle(color: titleColor),
                ),
                subtitle: Text(
                  config.dynamicTint
                      ? 'On — glass samples the colours behind it'
                      : 'Off — fixed tint, flat saturation, no mood swings',
                  style: TextStyle(color: subtitleColor, fontSize: 12.5),
                ),
                trailing: GlassSwitch(
                  value: config.dynamicTint,
                  onChanged: controller.setDynamicTint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('GEOMETRY', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              _buildRadiusTile(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                icon: CupertinoIcons.cube,
                color: const Color(0xFFFF375F),
                title: 'Bar radius',
                radius: config.barRadius,
                isAuto: config.barRadius == null,
                autoLabel: 'Capsule',
                onChanged: controller.setBarRadius,
              ),
              _buildRadiusTile(
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                icon: CupertinoIcons.dot_radiowaves_left_right,
                color: const Color(0xFF5856D6),
                title: 'Indicator radius',
                radius: config.indicatorRadius,
                isAuto: config.indicatorRadius == null,
                autoLabel: 'Auto',
                onChanged: controller.setIndicatorRadius,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LabActionButton(
                  icon: CupertinoIcons.arrow_counterclockwise,
                  label: 'Reset',
                  onTap: controller.reset,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabActionButton(
                  icon: CupertinoIcons.doc_text_fill,
                  label: 'Copy JSON',
                  onTap: () => _copyJson(context, controller),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabActionButton(
                  icon: CupertinoIcons.doc_on_doc,
                  label: 'Paste',
                  onTap: () => _pasteJson(context, controller),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('GLASS QUALITY', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: liquidGlassQualitySetting,
                builder: (context, quality, _) => _qualityTile(
                  context: context,
                  id: 'premium',
                  current: quality,
                  title: 'Premium',
                  subtitle: 'Full shader: refraction, rim and dispersion',
                  icon: CupertinoIcons.sparkles,
                  color: const Color(0xFF0A84FF),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: liquidGlassQualitySetting,
                builder: (context, quality, _) => _qualityTile(
                  context: context,
                  id: 'standard',
                  current: quality,
                  title: 'Standard',
                  subtitle: 'Lighter shader, still refracts the backdrop',
                  icon: CupertinoIcons.slider_horizontal_3,
                  color: const Color(0xFFFF9F0A),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: liquidGlassQualitySetting,
                builder: (context, quality, _) => _qualityTile(
                  context: context,
                  id: 'minimal',
                  current: quality,
                  title: 'Minimal',
                  subtitle: 'Blur only, for low-end GPUs and long lists',
                  icon: CupertinoIcons.minus_circle,
                  color: const Color(0xFF8E8E93),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('GLOW', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: glowModeSetting,
                builder: (context, mode, _) => _glowTile(
                  context: context,
                  id: 'off',
                  current: mode,
                  title: 'Off',
                  subtitle: 'No interaction glow — battery saver friendly',
                  icon: CupertinoIcons.moon,
                  color: const Color(0xFF8E8E93),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: glowModeSetting,
                builder: (context, mode, _) => _glowTile(
                  context: context,
                  id: 'subtle',
                  current: mode,
                  title: 'Subtle',
                  subtitle: 'Soft specular halo on buttons and menus',
                  icon: CupertinoIcons.sun_min,
                  color: const Color(0xFF0A84FF),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: glowModeSetting,
                builder: (context, mode, _) => _glowTile(
                  context: context,
                  id: 'dhruv',
                  current: mode,
                  title: 'Dhruv Mode',
                  subtitle: 'Wide, bright glow across every glass surface',
                  icon: CupertinoIcons.sparkles,
                  color: const Color(0xFFFF375F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GlassGroupedSection(
            header: _sectionHeader('RENDER PIPELINE', subtitleColor),
            surfaceStyle: GlassSurfaceStyle.solid,
            children: [
              Builder(
                builder: (tileContext) {
                  final tier = GlassAdaptiveScopeData.maybeOf(tileContext)
                          ?.effectiveQuality ??
                      GlassQuality.premium;
                  final tierName = tier == GlassQuality.premium
                      ? 'Premium'
                      : (tier == GlassQuality.standard
                          ? 'Standard'
                          : 'Minimal');
                  final hasShader = ui.ImageFilter.isShaderFilterSupported;

                  return GlassListTile(
                    leading: Icon(
                      CupertinoIcons.sparkles,
                      color: hasShader
                          ? const Color(0xFF30D158)
                          : const Color(0xFFFF9500),
                    ),
                    title: Text(
                      'Active render path',
                      style: TextStyle(color: titleColor),
                    ),
                    subtitle: Text(
                      hasShader
                          ? 'Impeller multi-pass shader · Tier: $tierName'
                          : 'Fallback blur engine · Tier: $tierName',
                      style: TextStyle(
                        color: hasShader
                            ? const Color(0xFF30D158)
                            : const Color(0xFFFF9500),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const MiniPlayerBottomSpace(),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassIconButton(
      size: 40,
      iconSize: 19,
      semanticLabel: 'Back',
      icon: Icon(
        CupertinoIcons.chevron_back,
        color: isDark ? Colors.white : Colors.black87,
        size: 19,
      ),
      onPressed: () => Navigator.of(context).pop(),
    );
  }

  Widget _sectionHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _qualityTile({
    required BuildContext context,
    required String id,
    required String current,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);
    final selected = current == id;

    return GlassListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor, fontSize: 12.5),
      ),
      trailing: selected
          ? Icon(CupertinoIcons.checkmark_circle_fill, color: color)
          : null,
      onTap: () {
        setLiquidGlassQuality(id);
        showToast(context, '$title quality selected');
      },
    );
  }

  Widget _glowTile({
    required BuildContext context,
    required String id,
    required String current,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);
    final selected = current == id;

    return GlassListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: titleColor, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor, fontSize: 12.5),
      ),
      trailing: selected
          ? Icon(CupertinoIcons.checkmark_circle_fill, color: color)
          : null,
      onTap: () {
        setGlowMode(id);
        showToast(context, '$title glow selected');
      },
    );
  }

  Widget _buildPreview(BuildContext context, GlassConfig config) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const GlassBackdrop(seedColor: Color(0xFFFF375F)),
            Align(
              alignment: const Alignment(0, -0.68),
              child: Text(
                'LIVE PREVIEW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: GlassSegmentedControl(
                segments: const [
                  GlassSegment(label: 'Home'),
                  GlassSegment(label: 'Library'),
                  GlassSegment(label: 'Canvas'),
                ],
                selectedIndex: 0,
                onSegmentSelected: (_) {},
                height: 52,
                borderRadius:
                    config.barRadius ?? GlassDefaults.capsuleRadius,
                indicatorBorderRadius: config.indicatorRadius,
                indicatorPinchStrength: config.pinchStrength,
                indicatorExpansion: EdgeInsets.symmetric(
                  horizontal: config.expansionH,
                  vertical: config.expansionV,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusTile({
    required Color titleColor,
    required Color subtitleColor,
    required IconData icon,
    required Color color,
    required String title,
    required double? radius,
    required bool isAuto,
    required String autoLabel,
    required ValueChanged<double?> onChanged,
  }) {
    final sliderValue = radius == null
        ? 24.0
        : radius.clamp(GlassConfig.radiusMin, GlassConfig.radiusMax).toDouble();

    return GlassListTile(
      leading: Icon(icon, color: color),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: titleColor)),
          Text(
            isAuto ? autoLabel : '${radius!.round()} px',
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GlassSlider(
          value: sliderValue,
          min: GlassConfig.radiusMin,
          max: GlassConfig.radiusMax,
          activeColor: color,
          onChanged: isAuto ? null : onChanged,
        ),
      ),
      trailing: GlassSwitch(
        value: isAuto,
        onChanged: (auto) => onChanged(auto ? null : 24),
      ),
    );
  }

  Widget _buildColorTile({
    required Color titleColor,
    required Color subtitleColor,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool inherited = false,
  }) {
    return GlassListTile(
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: titleColor.withValues(alpha: 0.16),
            width: 1,
          ),
        ),
      ),
      title: Text(title, style: TextStyle(color: titleColor)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor, fontSize: 12.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inherited)
            Text(
              'Auto',
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(width: 6),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 15,
            color: subtitleColor,
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _pickColor(
    BuildContext context,
    GlassConfigController controller, {
    required bool dock,
  }) async {
    const swatches = <int>[
      0xFFFFFFFF,
      0xFFF2F2F7,
      0xFF1C1C1E,
      0xFF000000,
      0xFF0A84FF,
      0xFF5E5CE6,
      0xFFBF5AF2,
      0xFFFF375F,
      0xFFFF9F0A,
      0xFF30D158,
      0xFF64D2FF,
      0xFFFFD60A,
    ];
    final current = Color(
      dock
          ? controller.config.dockTintColor ?? controller.config.tintColor
          : controller.config.tintColor,
    );

    await GlassModalSheet.show<void>(
      context: context,
      detents: const {GlassSheetDetent.medium},
      settings: glassSheetSettings(context),
      builder: (sheetContext) {
        final labelColor = glassSheetLabelColor(sheetContext);
        final subtitleColor = glassSheetSubtitleColor(sheetContext);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  dock ? 'Dock colour' : 'Glass colour',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: labelColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dock
                      ? 'Only the bottom dock changes. The rest of the glass keeps the global colour.'
                      : 'A base tint for every glass surface. Alpha stays in the Tint alpha slider.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 16),
                if (dock)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        controller.setDockTintColor(null);
                        Navigator.pop(sheetContext);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: labelColor.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              CupertinoIcons.arrow_uturn_left,
                              size: 18,
                              color: labelColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Inherit global glass colour',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: labelColor,
                                ),
                              ),
                            ),
                            if (controller.config.dockTintColor == null)
                              const Icon(
                                CupertinoIcons.checkmark_circle_fill,
                                size: 20,
                                color: Color(0xFF0A84FF),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final value in swatches)
                      GestureDetector(
                        onTap: () {
                          if (dock) {
                            controller.setDockTintColor(value);
                          } else {
                            controller.setTintColor(value);
                          }
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Color(value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Color(value) == current
                                  ? const Color(0xFF0A84FF)
                                  : CupertinoColors.separator.resolveFrom(
                                      sheetContext,
                                    ),
                              width: Color(value) == current ? 3 : 1,
                            ),
                          ),
                          child: Color(value) == current
                              ? Icon(
                                  CupertinoIcons.checkmark_alt,
                                  size: 18,
                                  color: Color(value).computeLuminance() > 0.55
                                      ? CupertinoColors.black
                                      : CupertinoColors.white,
                                )
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyJson(
    BuildContext context,
    GlassConfigController controller,
  ) async {
    await Clipboard.setData(ClipboardData(text: controller.exportJson()));
    if (!context.mounted) return;
    showToast(context, 'Glass config copied to clipboard');
  }

  Future<void> _pasteJson(
    BuildContext context,
    GlassConfigController controller,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!context.mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      showToast(context, 'Clipboard is empty');
      return;
    }
    final imported = controller.importJson(text);
    showToast(
      context,
      imported ? 'Glass config imported ✨' : 'That clipboard is not glass JSON',
    );
  }
}

class _LabSliderTile extends StatelessWidget {
  const _LabSliderTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF636366);

    return GlassListTile(
      leading: Icon(icon, color: color),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: titleColor)),
          Text(
            valueLabel,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: GlassSlider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          activeColor: color,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LabActionButton extends StatelessWidget {
  const _LabActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white : Colors.black87;

    return GlassButton.custom(
      onTap: onTap,
      height: 46,
      width: double.infinity,
      shape: const LiquidRoundedRectangle(borderRadius: 23),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
