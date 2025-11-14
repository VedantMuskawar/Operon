import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PageContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final bool showBorder;
  final bool showShadow;
  final bool fullHeight;

  const PageContainer({
    super.key,
    required this.child,
    this.padding,
    this.showBorder = false,
    this.showShadow = false,
    this.fullHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

        final content = Container(
          width: double.infinity,
          height: fullHeight && hasFiniteHeight ? constraints.maxHeight : null,
          decoration: BoxDecoration(
            // PaveBoard's radial gradient background
            gradient: const RadialGradient(
              center: Alignment(0.2, -0.1),
              radius: 1.2,
              colors: [
                Color(0xFF1F232A), // #1f232a
                Color(0xFF0B0D0F), // #0b0d0f
              ],
              stops: [0.0, 0.6],
            ),
            border: showBorder
                ? Border.all(
                    color: AppTheme.borderColor,
                    width: 1,
                  )
                : null,
            boxShadow: showShadow
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: padding ??
                const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLg,
                  vertical: AppTheme.spacingMd,
                ),
            child: child,
          ),
        );

        if (!fullHeight || !hasFiniteHeight) {
          return content;
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
          ),
          child: content,
        );
      },
    );
  }
}
