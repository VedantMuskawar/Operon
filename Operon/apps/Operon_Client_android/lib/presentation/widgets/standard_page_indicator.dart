import 'package:flutter/material.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

/// Standardized page indicator component
class StandardPageIndicator extends StatelessWidget {
  const StandardPageIndicator({
    super.key,
    required this.pageCount,
    required this.currentIndex,
  });

  final int pageCount;
  final double currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        pageCount,
        (index) {
          final isActive = currentIndex.round() == index;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.marginXS),
            width: isActive ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.textTertiary,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
            ),
          );
        },
      ),
    );
  }
}

