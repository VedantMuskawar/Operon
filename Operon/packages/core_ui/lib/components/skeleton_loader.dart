import 'package:flutter/material.dart';

/// A skeleton loader widget with shimmer effect
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.child,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? child;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
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
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0),
              end: Alignment(1.0 - _controller.value * 2, 0),
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF2A2A2A),
                const Color(0xFF1A1A1A),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// A skeleton loader for form fields
class SkeletonFormField extends StatelessWidget {
  const SkeletonFormField({
    super.key,
    this.height = 56,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonLoader(
          width: 100,
          height: 16,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        SkeletonLoader(
          width: double.infinity,
          height: height,
          borderRadius: BorderRadius.circular(16),
        ),
      ],
    );
  }
}

/// A skeleton loader for buttons
class SkeletonButton extends StatelessWidget {
  const SkeletonButton({
    super.key,
    this.height = 52,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      width: double.infinity,
      height: height,
      borderRadius: BorderRadius.circular(18),
    );
  }
}
