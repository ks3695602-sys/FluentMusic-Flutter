import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tintColor;
  final double? customBlur;
  final VoidCallback? onTap;
  final Border? customBorder;
  final bool isCircle;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 24.0,
    this.tintColor,
    this.customBlur,
    this.onTap,
    this.customBorder,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final shape = isCircle
        ? const LiquidShape.circle()
        : LiquidShape.roundedRectangle(borderRadius: borderRadius);

    Widget container = GlassContainer(
      useOwnLayer: true,
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16.0),
      shape: shape,
      child: child,
    );

    if (onTap != null) {
      container = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: container,
      );
    }

    if (margin != null) {
      container = Padding(
        padding: margin!,
        child: container,
      );
    }

    return container;
  }
}
