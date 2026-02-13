import 'dart:ui';

import 'package:core_ui/core_ui.dart' show AuthColors;
import 'package:flutter/material.dart';

/// Glassmorphism panel widget with frosted glass effect.
///
/// Creates a premium "frosted glass" appearance using BackdropFilter
/// that blurs content behind it, gradient border, and soft inner shadow
/// for material depth and a floating feel.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.blurSigma = 20.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
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
  /// Defaults to 18 for premium frosted effect (15–20px range).
  final double blurSigma;

  /// Background color with opacity. Defaults to white with 0.7 opacity.
  final Color? backgroundColor;

  /// Border color. Ignored when using gradient border; kept for API compatibility.
  final Color? borderColor;

  /// Width of the gradient border. Defaults to 1.5 for visible stroke.
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(24);
    final effectiveBackgroundColor =
        backgroundColor ?? Colors.black.withValues(alpha: 0.7);
    final effectivePadding = padding ?? const EdgeInsets.all(16);
    final innerRadius = effectiveBorderRadius.topLeft.x - borderWidth;
    final innerBorderRadius = BorderRadius.circular(innerRadius > 0 ? innerRadius : 12);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: effectiveBorderRadius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AuthColors.textMain.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: EdgeInsets.all(borderWidth),
              child: Container(
                padding: effectivePadding,
                decoration: BoxDecoration(
                  color: effectiveBackgroundColor,
                  borderRadius: innerBorderRadius,
                  boxShadow: [
                    // Soft inner shadow simulation: dark gradient overlay at top
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 0,
                      offset: const Offset(0, 1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    child,
                    // Soft inner shadow: subtle dark gradient at top edge
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 12,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: innerBorderRadius,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.03),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
