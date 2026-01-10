import 'package:flutter/material.dart';

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
        iconColor = Colors.orange;
        break;
      case ErrorType.permission:
        icon = Icons.lock_outline;
        iconColor = Colors.red;
        break;
      case ErrorType.notFound:
        icon = Icons.search_off;
        iconColor = Colors.white70;
        break;
      case ErrorType.generic:
        icon = Icons.error_outline;
        iconColor = Colors.redAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6F4BFF),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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

