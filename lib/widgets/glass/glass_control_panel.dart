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
 */

import 'dart:ui' show FontFeature;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Shared header for control sheets (Speed & Pitch, and future panels).
///
/// The panel itself adds no glass layer: it is meant to sit inside a single
/// [GlassModalSheet] or [GlassContainer.card]. Sliders and switches are safe
/// there because their glass is transient.
class GlassControlPanel extends StatelessWidget {
  const GlassControlPanel({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: CupertinoColors.white,
          ),
        ),
        if (subtitleText != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitleText,
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
        const SizedBox(height: 18),
        ...children,
        if (footer != null) ...[const SizedBox(height: 12), footer!],
      ],
    );
  }
}

/// One labelled slider with a live value badge and an optional reset action.
class GlassControlSlider extends StatelessWidget {
  const GlassControlSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.accent = const Color(0xFF0A84FF),
    this.onReset,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final int? divisions;
  final Color accent;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
              GestureDetector(
                onTap: onReset,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    valueLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          GlassSlider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            activeColor: accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A row of preset pills for a control panel.
///
/// Uses flat translucent pills on purpose: the parent sheet is already glass,
/// and nesting refractive buttons inside it is an anti-pattern.
class GlassControlPresets extends StatelessWidget {
  const GlassControlPresets({
    super.key,
    required this.presets,
    required this.onSelected,
  });

  /// Labels in display order.
  final List<String> presets;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets
          .map(
            (label) => CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              minSize: 0,
              borderRadius: BorderRadius.circular(20),
              color: CupertinoColors.white.withValues(alpha: 0.12),
              pressedOpacity: 0.7,
              onPressed: () => onSelected(label),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
