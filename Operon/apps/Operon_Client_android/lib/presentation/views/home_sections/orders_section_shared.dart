import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';

/// Shared empty state for Schedule Orders and Pending Orders views.
/// Uses AuthColors for consistent theming.
class OrdersSectionEmptyState extends StatelessWidget {
  const OrdersSectionEmptyState({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.9 + (0.1 * value),
            child: child,
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AuthColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: AuthColors.textMainWithOpacity(0.1),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AuthColors.textDisabled,
            ),
          ),
          const SizedBox(height: AppSpacing.paddingXXL),
          Text(
            title,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.paddingSM),
          Text(
            message,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Shared loading state for Schedule Orders and Pending Orders views.
/// Uses AuthColors-themed spinner.
class OrdersSectionLoadingState extends StatelessWidget {
  const OrdersSectionLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingXXL),
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
            backgroundColor: AuthColors.textMainWithOpacity(0.1),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loading layout for orders section (stats + list placeholders).
/// Uses AuthColors for consistent theming.
class OrdersSectionSkeletonLoading extends StatelessWidget {
  const OrdersSectionSkeletonLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _SkeletonStatTile()),
            const SizedBox(width: AppSpacing.paddingLG),
            Expanded(child: _SkeletonStatTile()),
          ],
        ),
        const SizedBox(height: AppSpacing.paddingXXL),
        ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.paddingMD),
              child: _SkeletonOrderTile(),
            )),
      ],
    );
  }
}

class _SkeletonStatTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.paddingLG, vertical: AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
            ),
          ),
          const SizedBox(width: AppSpacing.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  ),
                ),
                const SizedBox(height: AppSpacing.paddingSM),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonOrderTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.paddingLG),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.paddingSM),
                    Container(
                      width: 150,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: AuthColors.textMainWithOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.paddingMD),
          Row(
            children: List.generate(3, (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? AppSpacing.paddingSM : 0),
                    height: 32,
                    decoration: BoxDecoration(
                      color: AuthColors.textMainWithOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                    ),
                  ),
                )),
          ),
        ],
      ),
    );
  }
}
