import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Shared splash screen content widget
/// Displays loading state with consistent styling
class SplashContent extends StatelessWidget {
  const SplashContent({
    super.key,
    required this.message,
    this.showRetry = false,
    this.onRetry,
  });

  final String message;
  final bool showRetry;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Ensure MediaQuery has a safe textScaler to prevent configuration ID errors
    final mediaQuery = MediaQuery.maybeOf(context);
    final safeTextScaler = const TextScaler.linear(1.0);
    final safeMediaQuery = mediaQuery?.copyWith(textScaler: safeTextScaler) ?? 
        MediaQueryData(textScaler: safeTextScaler);
    
    return MediaQuery(
      data: safeMediaQuery,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Circular gradient dots
          const RepaintBoundary(
            child: ICloudDottedCircle(size: 120),
          ),
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [AuthColors.primary, AuthColors.primaryVariant],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.dashboard,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuthColors.primaryWithOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 16,
              fontFamily: 'SF Pro Display',
            ),
          ),
          if (showRetry && onRetry != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 50,
              child: FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AuthColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper function to get splash message from status
/// This is a generic helper that works with any status enum/string
String getSplashMessage(dynamic status) {
  if (status == null) return 'Loading...';
  
  final statusStr = status.toString().toLowerCase();
  
  if (statusStr.contains('checking') || statusStr.contains('auth')) {
    return 'Checking authentication...';
  }
  if (statusStr.contains('loading') && statusStr.contains('organization')) {
    return 'Loading organizations...';
  }
  if (statusStr.contains('restoring') || statusStr.contains('session')) {
    return 'Restoring session...';
  }
  if (statusStr.contains('error')) {
    return 'Error occurred';
  }
  
  return 'Loading...';
}
