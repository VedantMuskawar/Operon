import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Widget that handles Android system back button
/// Wraps pages to provide proper back navigation
class BackButtonHandler extends StatelessWidget {
  const BackButtonHandler({
    super.key,
    required this.child,
    this.onBack,
    this.canPop,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool? canPop;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
    
    // Determine if we should allow popping
    final shouldAllowPop = canPop ?? _shouldAllowPop(router, currentLocation);
    
    return PopScope(
      canPop: shouldAllowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        
        // If custom handler provided, use it
        if (onBack != null) {
          onBack!();
          return;
        }

        // Handle navigation based on current location
        _handleBackNavigation(context, router, currentLocation);
      },
      child: child,
    );
  }

  bool _shouldAllowPop(GoRouter router, String currentLocation) {
    // If we can pop in the router, allow it
    if (router.canPop()) {
      return true;
    }

    // If we're on home page and can't pop, prevent app from closing
    if (currentLocation == '/home') {
      return false; // Prevent app from closing
    }

    // For entry points (splash, login, org-selection), allow pop (will close app)
    // This is the default Android behavior
    if (currentLocation == '/splash' || 
        currentLocation == '/login' || 
        currentLocation == '/org-selection') {
      return true; // Allow app to close
    }
    
    // For other pages that can't pop, navigate to home instead
    return false;
  }

  void _handleBackNavigation(
    BuildContext context,
    GoRouter router,
    String currentLocation,
  ) {
    // If we can pop, do it
    if (router.canPop()) {
      router.pop();
      return;
    }

    // If we're on home page, do nothing (canPop is false, so app won't close)
    if (currentLocation == '/home') {
      return;
    }

    // For other root pages that can't pop, navigate to home
    if (currentLocation != '/home' && 
        currentLocation != '/splash' && 
        currentLocation != '/login' && 
        currentLocation != '/org-selection') {
      router.go('/home');
    }
  }
}

