/*
 *     Copyright (C) 2026 Valeri Gokadze
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
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:musify/utilities/artwork_provider.dart';

/// Colours lifted from the current cover, shared by the player's backdrop,
/// mesh and dock glow so the artwork is only analysed once.
abstract final class ArtworkPalette {
  static final Map<String, ColorScheme> _cache = {};
  static final Map<String, Future<ColorScheme?>> _pending = {};

  /// The palette already resolved for [url], if any.
  static ColorScheme? peek(String? url) {
    if (url == null || url.isEmpty) return null;
    return _cache[url];
  }

  /// Resolves the palette for [url] once; later callers share the result.
  static Future<ColorScheme?> resolve(String? url) {
    if (url == null || url.isEmpty) return Future.value(null);
    final cached = _cache[url];
    if (cached != null) return Future.value(cached);
    final pending = _pending[url];
    if (pending != null) return pending;

    final future = _resolve(url);
    _pending[url] = future;
    return future.whenComplete(() => _pending.remove(url));
  }

  static Future<ColorScheme?> _resolve(String url) async {
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: ArtworkProvider.get(url),
        brightness: Brightness.dark,
      ).timeout(const Duration(seconds: 8));

      // Covers that are mostly one dark tone produce a grey scheme; pushing
      // saturation and lightness back up keeps the mesh alive instead of
      // washing the player out.
      final tuned = scheme.copyWith(
        primary: _vivid(scheme.primary),
        secondary: _vivid(scheme.secondary),
        tertiary: _vivid(scheme.tertiary),
      );
      _cache[url] = tuned;
      return tuned;
    } catch (_) {
      return null;
    }
  }

  static Color _vivid(Color color) {
    final hsl = HSLColor.fromColor(color);
    final saturation = hsl.saturation.clamp(0.30, 0.90).toDouble();
    final lightness = hsl.lightness.clamp(0.34, 0.62).toDouble();
    return hsl.withSaturation(saturation).withLightness(lightness).toColor();
  }

  static void clear() {
    _cache.clear();
    _pending.clear();
  }
}

/// The drifting colour field behind the player.
///
/// Four soft radial blobs, taken from the cover, that breathe in and out of
/// each other. This is paint only: no blur filter, no image readback, so a
/// 60/120 Hz panel pays for four gradients and nothing else. The motion stops
/// entirely when the system asks for reduced motion or the setting is off.
class MeshBackdrop extends StatefulWidget {
  const MeshBackdrop({
    super.key,
    required this.artworkUrl,
    this.opacity = 0.55,
    this.enabled = true,
  });

  final String? artworkUrl;
  final double opacity;
  final bool enabled;

  @override
  State<MeshBackdrop> createState() => _MeshBackdropState();
}

class _MeshBackdropState extends State<MeshBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ColorScheme? _scheme;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    );
    _loadPalette();
  }

  @override
  void didUpdateWidget(covariant MeshBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUrl != widget.artworkUrl) {
      _loadPalette();
    }
    _syncTicker();
  }

  /// Runs the clock only while the mesh is actually on screen.
  ///
  /// The setting can be switched off, and the user can ask the system for
  /// reduced motion. In both cases the ticker must stop: an invisible
  /// animation is pure battery drain, and the player's backdrop is the one
  /// surface that never gets to be wasteful.
  void _syncTicker() {
    final shouldAnimate = widget.enabled && !_reduceMotion;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  Future<void> _loadPalette() async {
    final url = widget.artworkUrl;
    final cached = ArtworkPalette.peek(url);
    if (cached != null) {
      if (mounted) setState(() => _scheme = cached);
      return;
    }
    final resolved = await ArtworkPalette.resolve(url);
    if (!mounted) return;
    setState(() => _scheme = resolved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _syncTicker();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final scheme = _scheme;
    final colors = scheme == null
        ? const [
            Color(0xFF3A1F4D),
            Color(0xFF16223A),
            Color(0xFF2B1533),
            Color(0xFF101820),
          ]
        : <Color>[
            scheme.primary,
            scheme.secondary,
            scheme.tertiary,
            Color.lerp(scheme.primary, scheme.secondary, 0.5)!,
          ];

    final reduceMotion = _reduceMotion;
    if (reduceMotion) {
      return IgnorePointer(
        child: CustomPaint(
          painter: _MeshPainter(
            colors: colors,
            t: 0.35,
            opacity: widget.opacity,
          ),
        ),
      );
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _MeshPainter(
            colors: colors,
            t: _controller.value,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.colors,
    required this.t,
    required this.opacity,
  });

  final List<Color> colors;
  final double t;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Additive light only: the blurred cover stays visible underneath, the
    // mesh just lifts it. No saveLayer and no black fill, so the backdrop the
    // player already paid for is never thrown away. The layer's opacity is
    // folded into the gradients: a full-screen Opacity widget would allocate
    // a saveLayer on every single frame.
    for (var i = 0; i < colors.length; i++) {
      final phase = t * math.pi * 2 + i * 1.55;
      final speed = 0.7 + i * 0.11;
      final cx = size.width * (0.5 + 0.28 * math.sin(phase * speed));
      final cy = size.height * (0.42 + 0.26 * math.cos(phase * 0.83 + i));
      final radius = size.shortestSide * (0.58 + 0.07 * math.sin(phase * 1.3));
      final circle = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

      final shader = RadialGradient(
        colors: [
          colors[i].withValues(alpha: 0.55 * opacity),
          colors[i].withValues(alpha: 0.20 * opacity),
          colors[i].withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(circle);

      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MeshPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.opacity != opacity ||
      oldDelegate.colors != colors;
}

/// The soft coloured light under the player's controls.
///
/// Taken from the cover rather than the app accent, so the dock belongs to the
/// album instead of fighting it. Static: it is a gradient, not an animation.
class PlayerDockGlow extends StatefulWidget {
  const PlayerDockGlow({
    super.key,
    required this.artworkUrl,
    this.height = 300,
  });

  final String? artworkUrl;
  final double height;

  @override
  State<PlayerDockGlow> createState() => _PlayerDockGlowState();
}

class _PlayerDockGlowState extends State<PlayerDockGlow> {
  ColorScheme? _scheme;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerDockGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkUrl != widget.artworkUrl) _load();
  }

  Future<void> _load() async {
    final cached = ArtworkPalette.peek(widget.artworkUrl);
    if (cached != null) {
      if (mounted) setState(() => _scheme = cached);
      return;
    }
    final resolved = await ArtworkPalette.resolve(widget.artworkUrl);
    if (!mounted) return;
    setState(() => _scheme = resolved);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _scheme?.primary ?? const Color(0xFF8E7CFF);
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0.95),
                radius: 1.1,
                colors: [
                  accent.withValues(alpha: 0.34),
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A blurred band under the status bar that fades into the page.
///
/// This is the one live [BackdropFilter] the player allows: it sits in a
/// fixed-height strip inside the (static) backdrop layer, so it is rasterised
/// with the artwork and not on every playback tick.
class ProgressiveTopBlur extends StatelessWidget {
  const ProgressiveTopBlur({super.key, this.height = 148});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFFFFF),
                Color(0xAAFFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [0.0, 0.55, 1.0],
            ).createShader(bounds),
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: 16,
                  sigmaY: 16,
                  tileMode: TileMode.clamp,
                ),
                child: const ColoredBox(color: Color(0x01000000)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}