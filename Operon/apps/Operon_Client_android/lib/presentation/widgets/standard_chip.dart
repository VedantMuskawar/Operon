import 'package:flutter/material.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:core_ui/core_ui.dart';

/// Standardized chip component for filters and selections
class StandardChip extends StatelessWidget {
  const StandardChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius * 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.paddingLG,
          vertical: AppSpacing.paddingMD,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AuthColors.primary.withValues(alpha: 0.2)
              : AuthColors.surface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppSpacing.chipRadius * 2),
          border: Border.all(
            color: isSelected
                ? AuthColors.primary
                : AuthColors.textMainWithOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: AppSpacing.iconSM,
                color: isSelected
                    ? AuthColors.primary
                    : AuthColors.textSub,
              ),
              const SizedBox(width: AppSpacing.gapSM),
            ],
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected
                    ? AuthColors.textMain
                    : AuthColors.textSub,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

