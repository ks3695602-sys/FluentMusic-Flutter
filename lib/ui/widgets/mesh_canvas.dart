import 'dart:ui';
import 'package:flutter/material.dart';

/// Ambient OLED Backdrop.
/// Replaces cartoonish canvas circles with deep OLED black and subtle ambient glow.
class MeshCanvas extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final String? artworkUrl;

  const MeshCanvas({
    super.key,
    required this.child,
    this.colors,
    this.artworkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black, // Pure OLED Black
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle ambient radial glow at the top
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (colors != null && colors!.isNotEmpty ? colors!.first : const Color(0xFFFA2D48))
                        .withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Child content
          child,
        ],
      ),
    );
  }
}
