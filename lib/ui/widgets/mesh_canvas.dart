import 'dart:math';
import 'package:flutter/material.dart';

class MeshCanvas extends StatefulWidget {
  final List<Color> colors;
  final Widget child;

  const MeshCanvas({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  State<MeshCanvas> createState() => _MeshCanvasState();
}

class _MeshCanvasState extends State<MeshCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        final c1 = widget.colors.isNotEmpty ? widget.colors[0] : const Color(0xFF6C5CE7);
        final c2 = widget.colors.length > 1 ? widget.colors[1] : const Color(0xFF00CEC9);
        final c3 = widget.colors.length > 2 ? widget.colors[2] : const Color(0xFFE84393);

        return Stack(
          children: [
            // Dark base
            Container(color: const Color(0xFF090A0F)),

            // Gradient blob 1
            Positioned(
              top: -80 + sin(progress * 2 * pi) * 60,
              left: -60 + cos(progress * 2 * pi) * 60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c1.withValues(alpha: 0.35),
                ),
              ),
            ),

            // Gradient blob 2
            Positioned(
              bottom: 120 + cos(progress * 2 * pi) * 70,
              right: -50 + sin(progress * 2 * pi) * 70,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c2.withValues(alpha: 0.3),
                ),
              ),
            ),

            // Gradient blob 3
            Positioned(
              top: 280 + sin(progress * 2 * pi + 1) * 50,
              right: 40 + cos(progress * 2 * pi + 1) * 50,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c3.withValues(alpha: 0.25),
                ),
              ),
            ),

            // Blur filter overlay
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),

            // Foreground content
            Positioned.fill(child: widget.child),
          ],
        );
      },
    );
  }
}
