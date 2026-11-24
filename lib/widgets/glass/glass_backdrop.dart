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

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Colourful, low-cost backdrop that gives the glass something to refract.
///
/// Plain black backdrops are the main reason liquid glass looks dull/grey.
/// This widget paints a mesh of soft radial gradients (no blur filters, no
/// shaders) so refraction and chromatic dispersion become visible while
/// staying cheap on low-end GPUs.
///
/// Place this behind a *single* glass layer. Never wrap glass inside glass.
class GlassBackdrop extends StatefulWidget {
  /// Creates a backdrop. [seedColor] is usually the current album art colour.
  const GlassBackdrop({
    super.key,
    this.seedColor,
    this.animate = true,
    this.child,
  });

  /// Base hue for the gradient blobs. Defaults to FluentMusic red.
  final Color? seedColor;

  /// Slow ambient drift. Disable on long-lived backgrounds to save battery.
  final bool animate;

  /// Optional foreground content painted above the gradient.
  final Widget? child;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GlassBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness =
        MediaQuery.maybeOf(context)?.platformBrightness ?? Brightness.light;
    final isDark = brightness == Brightness.dark;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final seed = widget.seedColor ?? const Color(0xFFFA2D48);

    return RepaintBoundary(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final progress =
                (reduceMotion || !widget.animate) ? 0.35 : _controller.value;
            return CustomPaint(
              painter: _GlassBackdropPainter(
                seed: seed,
                isDark: isDark,
                progress: progress,
              ),
              child: child,
            );
          },
          child: widget.child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _GlassBackdropPainter extends CustomPainter {
  const _GlassBackdropPainter({
    required this.seed,
    required this.isDark,
    required this.progress,
  });

  final Color seed;
  final bool isDark;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final base = isDark
        ? const [Color(0xFF0B0712), Color(0xFF140D20), Color(0xFF050309)]
        : const [Color(0xFFFDF8FF), Color(0xFFF1F6FF), Color(0xFFF0FBF6)];

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: base,
        ).createShader(bounds),
    );

    final hsl = HSLColor.fromColor(seed);
    final secondary = hsl
        .withHue((hsl.hue + 55) % 360)
        .withSaturation((hsl.saturation + 0.15).clamp(0.35, 1.0).toDouble())
        .toColor();
    final accent = hsl
        .withHue((hsl.hue + 190) % 360)
        .withSaturation((hsl.saturation + 0.05).clamp(0.30, 1.0).toDouble())
        .toColor();
    final warm = hsl
        .withHue((hsl.hue + 310) % 360)
        .withSaturation((hsl.saturation + 0.20).clamp(0.40, 1.0).toDouble())
        .toColor();

    _paintBlob(canvas, size, seed, const Alignment(-0.75, -0.65), 0.05, 0.00);
    _paintBlob(canvas, size, secondary, const Alignment(0.80, -0.55), 0.06, 0.25);
    _paintBlob(canvas, size, accent, const Alignment(-0.55, 0.75), 0.05, 0.50);
    _paintBlob(canvas, size, warm, const Alignment(0.85, 0.70), 0.04, 0.75);
  }

  void _paintBlob(
    Canvas canvas,
    Size size,
    Color color,
    Alignment anchor,
    double drift,
    double phase,
  ) {
    final angle = (progress + phase) * 2 * math.pi;
    final center = Offset(
      size.width * (0.5 + anchor.x * 0.5) +
          math.cos(angle) * size.width * drift,
      size.height * (0.5 + anchor.y * 0.5) +
          math.sin(angle) * size.height * drift,
    );
    final radius = size.shortestSide * 0.72;
    final alpha = isDark ? 0.55 : 0.34;

    final shader = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _GlassBackdropPainter oldDelegate) {
    return oldDelegate.seed != seed ||
        oldDelegate.isDark != isDark ||
        oldDelegate.progress != progress;
  }
}
