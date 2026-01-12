import 'package:flutter/material.dart';

/// A widget that slides in its child with optional fade
class SlideInTransition extends StatefulWidget {
  const SlideInTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.delay = Duration.zero,
    this.curve = Curves.easeInOut,
    this.offset = const Offset(0, 0.1),
    this.fade = true,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset offset;
  final bool fade;

  @override
  State<SlideInTransition> createState() => _SlideInTransitionState();
}

class _SlideInTransitionState extends State<SlideInTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.fade) {
      _fadeAnimation = CurvedAnimation(
        parent: _controller,
        curve: widget.curve,
      );
    }

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget child = SlideTransition(
      position: _slideAnimation,
      child: widget.child,
    );

    if (widget.fade) {
      child = FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      );
    }

    return child;
  }
}
