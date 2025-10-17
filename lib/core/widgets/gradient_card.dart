import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientCard extends StatelessWidget {
  final Widget child;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final bool useGlassMorphism;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding,
    this.margin,
    this.elevation,
    this.useGlassMorphism = false,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cardGradient = gradient ?? AppTheme.cardGradient;
    final cardElevation = elevation ?? 4.0;
    final cardBorderRadius = borderRadius ?? BorderRadius.circular(16);

    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: BoxDecoration(
        gradient: useGlassMorphism ? AppTheme.glassGradient : cardGradient,
        borderRadius: cardBorderRadius,
        border: useGlassMorphism 
            ? Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          if (useGlassMorphism) ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] else ...[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: cardElevation * 2,
              offset: Offset(0, cardElevation / 2),
            ),
          ],
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: cardBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}

class GradientCardWithGlow extends StatelessWidget {
  final Widget child;
  final LinearGradient gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? glowColor;

  const GradientCardWithGlow({
    super.key,
    required this.child,
    required this.gradient,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final glow = glowColor ?? AppTheme.primaryColor;

    Widget cardContent = Container(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: cardBorderRadius,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 0),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: cardBorderRadius,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
