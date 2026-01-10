import 'package:flutter/material.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

/// Modern tile component with glassmorphism effects
/// Provides consistent styling across all list items
class ModernTile extends StatelessWidget {
  const ModernTile({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderColor,
    this.accentColor,
    this.showShadow = true,
    this.elevation = 0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? borderColor;
  final Color? accentColor;
  final bool showShadow;
  final int elevation; // 0 = flat, 1 = elevated, 2 = highly elevated

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ?? 
        (accentColor?.withOpacity(0.2) ?? AppColors.borderDefault);
    final effectivePadding = padding ?? const EdgeInsets.all(AppSpacing.paddingLG);
    final effectiveMargin = margin ?? EdgeInsets.zero;

    // Shadow based on elevation
    final shadow = elevation == 0 
        ? (showShadow ? AppShadows.card : AppShadows.none)
        : elevation == 1 
            ? AppShadows.cardElevated 
            : AppShadows.cardHover;

    // Background gradient based on elevation
    final backgroundColor = elevation == 0
        ? AppColors.cardBackground
        : elevation == 1
            ? AppColors.cardBackgroundElevated
            : AppColors.cardBackgroundHover;

    Widget content = Container(
      padding: effectivePadding,
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: effectiveBorderColor,
          width: 1,
        ),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: content,
      );
    }

    return content;
  }
}

/// Modern tile with avatar and content
class ModernTileWithAvatar extends StatelessWidget {
  const ModernTileWithAvatar({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.avatarColor,
    this.avatarText,
    this.avatarIcon,
    this.badge,
    this.metadata,
    this.elevation = 0,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? avatarColor;
  final String? avatarText;
  final IconData? avatarIcon;
  final Widget? badge;
  final Widget? metadata;
  final int elevation;

  Color _getDefaultAvatarColor() {
    final hash = title.hashCode;
    const colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2 ? name.substring(0, 2).toUpperCase() : name.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveAvatarColor = avatarColor ?? _getDefaultAvatarColor();
    final effectiveAvatarText = avatarText ?? _getInitials(title);

    return ModernTile(
      onTap: onTap,
      accentColor: effectiveAvatarColor,
      elevation: elevation,
      child: Row(
        children: [
          // Avatar
          Container(
            width: AppSpacing.avatarMD,
            height: AppSpacing.avatarMD,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  effectiveAvatarColor,
                  effectiveAvatarColor.withOpacity(0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: effectiveAvatarColor.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Center(
              child: avatarIcon != null
                  ? Icon(
                      avatarIcon,
                      color: AppColors.textPrimary,
                      size: AppSpacing.iconMD,
                    )
                  : Text(
                      effectiveAvatarText,
                      style: AppTypography.h4.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),
          ),
          SizedBox(width: AppSpacing.itemSpacing),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: AppTypography.h4,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: AppSpacing.paddingXS),
                      badge!,
                    ],
                  ],
                ),
                SizedBox(height: AppSpacing.paddingXS),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata != null) ...[
                  SizedBox(height: AppSpacing.paddingXS),
                  metadata!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: AppSpacing.itemSpacing),
            trailing!,
          ] else if (onTap != null) ...[
            SizedBox(width: AppSpacing.itemSpacing),
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
              size: AppSpacing.iconSM,
            ),
          ],
        ],
      ),
    );
  }
}

/// Modern tile for products/inventory items
class ModernProductTile extends StatelessWidget {
  const ModernProductTile({
    super.key,
    required this.name,
    required this.price,
    required this.status,
    this.gstPercent,
    this.fixedQuantityOptions,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.canEdit = false,
    this.canDelete = false,
    this.elevation = 0,
  });

  final String name;
  final double price;
  final String status;
  final double? gstPercent;
  final List<String>? fixedQuantityOptions;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool canEdit;
  final bool canDelete;
  final int elevation;

  @override
  Widget build(BuildContext context) {
    return ModernTile(
      onTap: onTap,
      elevation: elevation,
      child: Row(
        children: [
          // Icon
          Container(
            width: AppSpacing.avatarMD,
            height: AppSpacing.avatarMD,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2),
              ),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: AppSpacing.iconMD,
            ),
          ),
          SizedBox(width: AppSpacing.itemSpacing),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTypography.h4,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppSpacing.paddingXS),
                Text(
                  gstPercent != null
                      ? '₹${price.toStringAsFixed(2)} • GST ${gstPercent!.toStringAsFixed(1)}%'
                      : '₹${price.toStringAsFixed(2)} • No GST',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (fixedQuantityOptions != null &&
                    fixedQuantityOptions!.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.paddingXS / 2),
                  Text(
                    'Fixed Qty/Trip: ${fixedQuantityOptions!.join(", ")}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                SizedBox(height: AppSpacing.paddingXS / 2),
                Text(
                  'Status: $status',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          if (canEdit || canDelete)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (canEdit)
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: AppColors.textSecondary,
                      size: AppSpacing.iconSM,
                    ),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (canEdit && canDelete)
                  SizedBox(height: AppSpacing.paddingXS),
                if (canDelete)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                      size: AppSpacing.iconSM,
                    ),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

