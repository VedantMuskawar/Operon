import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_mobile/shared/constants/constants.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;

/// Modern page header with back button and centered title
/// Provides consistent styling and navigation across all pages
class ModernPageHeader extends StatelessWidget implements PreferredSizeWidget {
  const ModernPageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.showBackButton = true,
    this.centerTitle = true,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showBackButton;
  final bool centerTitle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
    } else {
      // Default behavior: go back if possible, otherwise go to home
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AuthColors.primary,
      elevation: 0,
      leading: showBackButton
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary,
                  size: AppSpacing.iconMD,
                ),
                onPressed: () => _handleBack(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            )
          : null,
      leadingWidth: showBackButton ? 56 : 0,
      title: centerTitle
          ? Flexible(
              child: Text(
                title,
                style: AppTypography.h2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
          : Text(
              title,
              style: AppTypography.h2,
            ),
      centerTitle: centerTitle,
      titleSpacing: 0,
      actions: actions ?? [const SizedBox(width: 48)], // Balance the leading width
      automaticallyImplyLeading: false,
    );
  }
}

