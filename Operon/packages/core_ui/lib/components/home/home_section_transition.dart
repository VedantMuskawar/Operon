import 'package:flutter/material.dart';

/// Home section transition widget for smooth fade-through animations
/// 
/// Provides consistent transitions between home sections while preserving
/// child widget state. Used in both Android and Web home pages.
class HomeSectionTransition extends StatelessWidget {
  const HomeSectionTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.enableSlide = false,
  });

  final Widget child;
  final Duration duration;
  final bool enableSlide;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        if (enableSlide) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.1, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        }
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}
