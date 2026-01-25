import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:core_ui/core_ui.dart';

/// Contact tile skeleton with shimmer effect for loading state
class ContactTileSkeleton extends StatelessWidget {
  const ContactTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AuthColors.textMainWithOpacity(0.05),
      highlightColor: AuthColors.textMainWithOpacity(0.15),
      period: const Duration(milliseconds: 1200),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              // Text skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 150,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 100,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron placeholder
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List of contact skeletons for loading state
class ContactListSkeleton extends StatelessWidget {
  const ContactListSkeleton({
    super.key,
    this.itemCount = 10,
    this.itemHeight = 72,
  });

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemExtent: itemHeight,
      itemBuilder: (context, index) {
        return const ContactTileSkeleton();
      },
    );
  }
}
