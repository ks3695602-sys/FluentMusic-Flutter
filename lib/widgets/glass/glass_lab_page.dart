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
import 'package:musify/theme/glass_config.dart';
import 'package:musify/theme/glass_config_controller.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/glass/glass_backdrop.dart';
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
                icon: CupertinoIcons.waveform,
                color: const Color(0xFFFF9500),
                title: 'Refraction',
                valueLabel: config.refraction.toStringAsFixed(2),
                value: config.refraction,
                min: GlassConfig.refractionMin,
                max: GlassConfig.refractionMax,
                onChanged: controller.setRefraction,
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
    return Padding(
      padding: const EdgeInsets.all(6),
      child: GlassIconButton(
        icon: Icon(
          CupertinoIcons.chevron_back,
          color: isDark ? Colors.white : Colors.black87,
          size: 20,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
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
