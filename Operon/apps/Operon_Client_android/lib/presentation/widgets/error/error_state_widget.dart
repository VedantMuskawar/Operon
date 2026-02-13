import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';

enum ErrorType {
  network,
  permission,
  notFound,
  generic,
}

/// Reusable error widget with icon, message, and retry button
class ErrorStateWidget extends StatelessWidget {
  const ErrorStateWidget({
    super.key,
    required this.message,
    this.errorType = ErrorType.generic,
    this.onRetry,
    this.retryLabel = 'Retry',
  });

  final String message;
  final ErrorType errorType;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;

    switch (errorType) {
      case ErrorType.network:
        icon = Icons.wifi_off;
        iconColor = AuthColors.secondary;
        break;
      case ErrorType.permission:
        icon = Icons.lock_outline;
        iconColor = AuthColors.error;
        break;
      case ErrorType.notFound:
        icon = Icons.search_off;
        iconColor = AuthColors.textSub;
        break;
      case ErrorType.generic:
        icon = Icons.error_outline;
        iconColor = AuthColors.error;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.paddingXXL),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor,
            ),
            const SizedBox(height: AppSpacing.paddingLG),
            Text(
              message,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.paddingXXL),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.legacyAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSM),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

