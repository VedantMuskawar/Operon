import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FormContainer extends StatelessWidget {
  final Widget child;
  final String? title;
  final EdgeInsets? padding;
  final bool showBorder;

  const FormContainer({
    super.key,
    required this.child,
    this.title,
    this.padding,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: showBorder
            ? Border.all(
                color: AppTheme.borderColor,
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingLg,
                AppTheme.spacingLg,
                AppTheme.spacingLg,
                AppTheme.spacingSm,
              ),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(0.5),
              ),
            ),
          ],
          
          // Content
          Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingLg),
            child: child,
          ),
        ],
      ),
    );
  }
}

