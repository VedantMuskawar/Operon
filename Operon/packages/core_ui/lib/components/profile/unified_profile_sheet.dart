import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../theme/auth_colors.dart';

/// Unified adaptive profile sheet component that works consistently across platforms.
/// 
/// On mobile: Renders as a Drawer with gradient overlay background.
/// On web/desktop: Renders as an animated side sheet sliding from the left.
/// 
/// Features:
/// - Consistent header with logo, app name, and close button
/// - Adaptive width (85% mobile, 350px desktop)
/// - Shared animation (SlideTransition with easeOutCubic)
/// - Dark gradient overlay for premium look
class UnifiedProfileSheet extends StatelessWidget {
  const UnifiedProfileSheet({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.child,
    this.appName = 'Operon',
    this.logoAssetPath = 'assets/branding/operon_app_icon.png',
  });

  /// Whether the sheet is currently open
  final bool isOpen;
  
  /// Callback when the sheet should be closed
  final VoidCallback onClose;
  
  /// The content widget (typically ProfileView)
  final Widget child;
  
  /// App name to display in header
  final String appName;
  
  /// Path to the logo asset
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600 || (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

    if (isMobile) {
      return _MobileDrawerSheet(
        isOpen: isOpen,
        onClose: onClose,
        child: child,
        appName: appName,
        logoAssetPath: logoAssetPath,
      );
    } else {
      return _WebSideSheet(
        isOpen: isOpen,
        onClose: onClose,
        child: child,
        appName: appName,
        logoAssetPath: logoAssetPath,
      );
    }
  }
}

/// Mobile implementation using animated side sheet (similar to web but with mobile width)
class _MobileDrawerSheet extends StatelessWidget {
  const _MobileDrawerSheet({
    required this.isOpen,
    required this.onClose,
    required this.child,
    required this.appName,
    required this.logoAssetPath,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final String appName;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.65).clamp(280.0, 400.0); // Match settings sheet width

    return Stack(
      children: [
        // Gradient overlay
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: AnimatedOpacity(
                opacity: isOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Animated side sheet - matching settings sheet style
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          left: isOpen ? 0 : -width,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(
                      appName: appName,
                      logoAssetPath: logoAssetPath,
                      onClose: onClose,
                    ),
                    Expanded(
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Web/Desktop implementation using animated side sheet
class _WebSideSheet extends StatelessWidget {
  const _WebSideSheet({
    required this.isOpen,
    required this.onClose,
    required this.child,
    required this.appName,
    required this.logoAssetPath,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final Widget child;
  final String appName;
  final String logoAssetPath;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final width = (screenWidth * 0.65).clamp(280.0, 400.0); // Match settings sheet width

    return Stack(
      children: [
        // Gradient overlay
        if (isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: AnimatedOpacity(
                opacity: isOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.7),
                        Colors.black.withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Animated side sheet - matching settings sheet style
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          top: 0,
          bottom: 0,
          left: isOpen ? 0 : -width,
          child: SizedBox(
            width: width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: const BoxDecoration(
                  color: AuthColors.surface,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(
                      appName: appName,
                      logoAssetPath: logoAssetPath,
                      onClose: onClose,
                    ),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Consistent header component with logo, app name, and close button
/// Matches settings sheet header style
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.appName,
    required this.logoAssetPath,
    required this.onClose,
  });

  final String appName;
  final String logoAssetPath;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                logoAssetPath,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AuthColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.business_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              appName,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
                letterSpacing: -0.2,
                height: 1.3,
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(10),
              splashColor: AuthColors.textMain.withValues(alpha: 0.1),
              highlightColor: AuthColors.textMain.withValues(alpha: 0.05),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.close_rounded,
                  color: AuthColors.textMain,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
