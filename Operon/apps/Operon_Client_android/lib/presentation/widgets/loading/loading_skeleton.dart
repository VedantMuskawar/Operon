import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Generic skeleton loader widget with shimmer effect
class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AuthColors.textMainWithOpacity(0.05),
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    );
  }
}

/// Client tile skeleton for loading state
class ClientTileSkeleton extends StatelessWidget {
  const ClientTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: const Row(
        children: [
          // Avatar skeleton
          LoadingSkeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          SizedBox(width: 16),
          // Text skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: 150, height: 16),
                SizedBox(height: 8),
                LoadingSkeleton(width: 100, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trip card skeleton for loading state
class TripCardSkeleton extends StatelessWidget {
  const TripCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LoadingSkeleton(width: 200, height: 16),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: LoadingSkeleton(width: double.infinity, height: 14)),
              SizedBox(width: 16),
              Expanded(child: LoadingSkeleton(width: double.infinity, height: 14)),
            ],
          ),
          SizedBox(height: 12),
          LoadingSkeleton(width: 100, height: 14),
        ],
      ),
    );
  }
}

/// List skeleton with multiple items
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    required this.itemBuilder,
    this.itemCount = 5,
    this.itemHeight,
  });

  final Widget Function(BuildContext, int) itemBuilder;
  final int itemCount;
  final double? itemHeight;

  @override
  Widget build(BuildContext context) {
    if (itemHeight != null) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemExtent: itemHeight,
        itemBuilder: itemBuilder,
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

