/*
 *     Copyright (C) 2026 jaypakash sahu
 *
 *     FluentMusic is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Resolves the brightness a sheet should paint in.
///
/// Sheets are rendered in the navigator overlay, so a page-local glass
/// brightness override does not reach [GlassModalSheet.show]'s builder
/// context. Callers that own a local override pass it in explicitly.
Brightness resolveSheetBrightness(BuildContext context, [Brightness? override]) {
  return override ?? GlassTheme.brightnessOf(context);
}

/// Explicit glass material for modal sheets.
///
/// The app's global tint is intentionally clear on iOS 27, which makes a sheet
/// almost invisible over bright artwork. Sheets are the one surface that needs
/// its own readable film, so they get a fixed light/dark tint here.
LiquidGlassSettings glassSheetSettings(
  BuildContext context, {
  Brightness? brightness,
}) {
  final isDark = resolveSheetBrightness(context, brightness) == Brightness.dark;
  final theme = GlassTheme.maybeOf(context)?.data;
  final variant = isDark ? theme?.dark : theme?.light;
  final base = (variant?.settings ?? const GlassThemeSettings())
      .applyTo(const LiquidGlassSettings());
  return base.copyWith(
    glassColor: (isDark ? CupertinoColors.black : CupertinoColors.white)
        .withValues(alpha: isDark ? 0.40 : 0.55),
    frost: 12,
    blur: 4,
  );
}

/// Resolves a label colour that stays readable on a glass sheet.
Color glassSheetLabelColor(BuildContext context, {Brightness? brightness}) {
  return resolveSheetBrightness(context, brightness) == Brightness.dark
      ? CupertinoColors.white
      : const Color(0xFF1C1C1E);
}

/// Secondary label colour for glass sheet captions.
Color glassSheetSubtitleColor(BuildContext context, {Brightness? brightness}) {
  return resolveSheetBrightness(context, brightness) == Brightness.dark
      ? CupertinoColors.white.withValues(alpha: 0.68)
      : const Color(0xFF636366);
}

/// Pins text resolution to the dark variant for menus whose glass is forced
/// dark over artwork.
///
/// Menus render in the nearest [OverlayPortal], which keeps this subtree's
/// inherited themes. Now Playing pins its glass dark even in light mode, so
/// the Cupertino text theme has to follow; otherwise [GlassMenuItem] resolves
/// black labels against the dark platter.
class DarkGlassMenuTheme extends StatelessWidget {
  const DarkGlassMenuTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(brightness: Brightness.dark),
      child: child,
    );
  }
}
