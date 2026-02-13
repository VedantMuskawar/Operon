import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/constants.dart';

/// Modern tile component with glassmorphism effects
/// Uses AuthColors for theme consistency with DashTheme.
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

  static List<BoxShadow> _cardShadow() => [
        BoxShadow(
          color: AuthColors.background.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];
  static List<BoxShadow> _cardElevatedShadow() => [
        BoxShadow(
          color: AuthColors.background.withValues(alpha: 0.4),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: AuthColors.background.withValues(alpha: 0.2),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> _cardHoverShadow() => [
        BoxShadow(
          color: AuthColors.background.withValues(alpha: 0.5),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final effectiveBorderColor = borderColor ??
      (accentColor?.withValues(alpha: 0.2) ?? AuthColors.textMainWithOpacity(0.1));
    final effectivePadding =
        padding ?? const EdgeInsets.all(AppSpacing.paddingLG);
    final effectiveMargin = margin ?? EdgeInsets.zero;

    final List<BoxShadow> shadow = elevation == 0
        ? (showShadow ? _cardShadow() : const <BoxShadow>[])
        : elevation == 1
            ? _cardElevatedShadow()
            : _cardHoverShadow();

    final backgroundColor = elevation == 0
        ? AuthColors.surface
        : elevation == 1
            ? AuthColors.surface
            : AuthColors.backgroundAlt;

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
      AuthColors.primary,
      AuthColors.success,
      AuthColors.warning,
      AuthColors.info,
      AuthColors.error,
    ];
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.length >= 2
        ? name.substring(0, 2).toUpperCase()
        : name.toUpperCase();
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
                  effectiveAvatarColor.withValues(alpha: 0.7),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: effectiveAvatarColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: -1,
                ),
              ],
            ),
            child: Center(
              child: avatarIcon != null
                  ? Icon(
                      avatarIcon,
                      color: AuthColors.textMain,
                      size: AppSpacing.iconMD,
                    )
                  : Text(
                      effectiveAvatarText,
                      style: AppTypography.h4.copyWith(
                        color: AuthColors.textMain,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.itemSpacing),
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
                        style: AppTypography.h4
                            .copyWith(color: AuthColors.textMain),
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
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(
                    color: AuthColors.textSub,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metadata != null) ...[
                  const SizedBox(height: AppSpacing.paddingXS),
                  metadata!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.itemSpacing),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: AppSpacing.itemSpacing),
            const Icon(
              Icons.chevron_right,
              color: AuthColors.textDisabled,
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
                  AuthColors.primary.withValues(alpha: 0.3),
                  AuthColors.primary.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMD),
              border: Border.all(
                color: AuthColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AuthColors.primary,
              size: AppSpacing.iconMD,
            ),
          ),
          const SizedBox(width: AppSpacing.itemSpacing),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: AppTypography.h4.copyWith(color: AuthColors.textMain),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.paddingXS),
                Text(
                  gstPercent != null
                      ? '₹${price.toStringAsFixed(2)} • GST ${gstPercent!.toStringAsFixed(1)}%'
                      : '₹${price.toStringAsFixed(2)} • No GST',
                  style: AppTypography.bodySmall.copyWith(
                    color: AuthColors.textSub,
                  ),
                ),
                if (fixedQuantityOptions != null &&
                    fixedQuantityOptions!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.paddingXS / 2),
                  Text(
                    'Fixed Qty/Trip: ${fixedQuantityOptions!.join(", ")}',
                    style: AppTypography.caption.copyWith(
                      color: AuthColors.textDisabled,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.paddingXS / 2),
                Text(
                  'Status: $status',
                  style: AppTypography.caption.copyWith(
                    color: AuthColors.textDisabled,
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
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: AuthColors.textSub,
                      size: AppSpacing.iconSM,
                    ),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (canEdit && canDelete)
                  const SizedBox(height: AppSpacing.paddingXS),
                if (canDelete)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AuthColors.error,
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
