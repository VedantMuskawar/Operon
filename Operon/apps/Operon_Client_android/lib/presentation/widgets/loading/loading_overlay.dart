import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';

/// Overlay widget that shows loading indicator and prevents interaction
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    this.isLoading = false,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.paddingLG),
                      Text(
                        message!,
                        style: const TextStyle(color: AuthColors.textSub),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Modal loading overlay for full-screen blocking
class ModalLoadingOverlay extends StatelessWidget {
  const ModalLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          ModalBarrier(
            dismissible: false,
            color: Colors.black.withOpacity(0.5),
          ),
        if (isLoading)
          Center(
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.paddingXXL),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  if (message != null) ...[
                    const SizedBox(height: AppSpacing.paddingLG),
                    Text(
                      message!,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

