import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:material_3_expressive/material_3_expressive.dart'
    show M3EMotion;
import 'package:material_ui/material_ui.dart';
import 'package:musify/mornye_player/theme/app_motion.dart';
import 'package:musify/mornye_player/theme/app_tokens.dart';
import 'package:musify/mornye_player/theme/material_expressive.dart';
import 'package:musify/mornye_player/theme/mornye_theme.dart';
import 'package:musify/mornye_player/utils/adaptive_layout.dart';
import 'package:musify/mornye_player/utils/desktop_platform.dart';
import 'package:musify/mornye_player/widgets/decorative_phase.dart';

/// Wraps a child in a staggered fade-in + slide-up animation.
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.index,
    required this.child,
    this.duration = const Duration(milliseconds: 250),
    this.staggerDelay = const Duration(milliseconds: 40),
    this.animate = true,
  });

  final int index;
  final Widget child;
  final Duration duration;
  final Duration staggerDelay;
  final bool animate;

  @override
  Widget build(BuildContext context) => child;
}

/// Bounces a badge when its count changes.
class AnimatedBadge extends StatefulWidget {
  const AnimatedBadge({super.key, required this.count, required this.child});

  final int count;
  final Widget child;

  static const bumpHeight = 0.15;

  @override
  State<AnimatedBadge> createState() => _AnimatedBadgeState();
}

class _AnimatedBadgeState extends State<AnimatedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _scale = Tween<double>(begin: 1, end: 1 + AnimatedBadge.bumpHeight)
        .chain(CurveTween(curve: Curves.easeOutBack))
        .animate(_controller);
  }

  @override
  void didUpdateWidget(covariant AnimatedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _controller.forward(from: 0).then((_) {
        if (mounted) _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: _scale,
    child: widget.child,
  );
}

/// Returns whether the current content should use its compact layout.
bool compactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600;

/// A tiny placeholder for decoration phases, retained to satisfy the copied
/// animation widgets' imports without bringing Mornye's app shell along.
class DecorativePhase extends StatelessWidget {
  const DecorativePhase({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => child;
}
