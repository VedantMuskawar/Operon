import 'dart:ui';

import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';

/// Glassmorphism panel widget with frosted glass effect.
/// 
/// Creates a premium "frosted glass" appearance using BackdropFilter
/// that blurs content behind it while maintaining visibility of the panel content.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.blurSigma = 10.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.5,
  });

  /// The widget to display inside the glass panel.
  final Widget child;

  /// Border radius for the panel. Defaults to 16.
  final BorderRadius? borderRadius;

  /// Padding inside the panel.
  final EdgeInsetsGeometry? padding;

  /// Margin around the panel.
  final EdgeInsetsGeometry? margin;

  /// Blur sigma value for the backdrop filter. Higher values = more blur.
  /// Defaults to 10.0 for optimal frosted effect.
  final double blurSigma;

  /// Background color with opacity. Defaults to white with 0.7 opacity.
  final Color? backgroundColor;

  /// Border color. Defaults to white.
  final Color? borderColor;

  /// Border width. Defaults to 0.5 for subtle edge effect.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final effectiveBackgroundColor =
        backgroundColor ?? Colors.white.withOpacity(0.7);
    final effectiveBorderColor = borderColor ?? Colors.white;
    final effectivePadding = padding ?? const EdgeInsets.all(16);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: effectivePadding,
              decoration: BoxDecoration(
                color: effectiveBackgroundColor,
                borderRadius: effectiveBorderRadius,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.textMain.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
