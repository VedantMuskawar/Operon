import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Wraps SliverList with fast staggered animations
/// - Duration: 200ms (fast)
/// - Delay: 30ms per item (quick stagger)
class AnimatedSliverList extends StatelessWidget {
  const AnimatedSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final bool addSemanticIndexes;

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 200),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  curve: Curves.easeOut,
                  child: itemBuilder(context, index),
                ),
              ),
            );
          },
          childCount: itemCount,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          addSemanticIndexes: addSemanticIndexes,
        ),
      ),
    );
  }
}
