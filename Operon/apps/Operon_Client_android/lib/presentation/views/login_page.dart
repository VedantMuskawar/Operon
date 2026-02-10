import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class LoginPageShell extends StatelessWidget {
  const LoginPageShell({
    super.key,
    required this.child,
    this.title = '',
  });

  final Widget child;
  final String title;

  static const _outerBackground = AuthColors.background;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _outerBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 700;
          if (isCompact) {
            return _MobileLoginShell(
              title: title,
              child: child,
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.paddingXXL,
                  vertical: AppSpacing.paddingXXXL),
              child: RepaintBoundary(
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _LoginContent(
                        title: title,
                        child: child,
                      ),
                    ),
                    const Expanded(
                      flex: 7,
                      child: _HeroPanel(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 56,
          vertical: 48,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: _LoginFormCard(title: title, child: child),
        ),
      ),
    );
  }
}

class _HeroPanel extends StatefulWidget {
  const _HeroPanel();

  @override
  State<_HeroPanel> createState() => _HeroPanelState();
}

class _HeroPanelState extends State<_HeroPanel> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Lazy load decorative elements
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _isLoaded = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(AppSpacing.paddingXXXXL),
        bottomRight: Radius.circular(AppSpacing.paddingXXXXL),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AuthColors.background,
              AuthColors.backgroundAlt,
              AuthColors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: RepaintBoundary(
          child: Stack(
            children: [
              if (_isLoaded)
                Positioned(
                  top: 120,
                  right: 140,
                  child: AnimatedFade(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.avatarSM * 1.5),
                        gradient: LinearGradient(
                          colors: [
                            AuthColors.secondary.withOpacity(0.2),
                            AuthColors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AuthColors.secondary.withOpacity(0.25),
                            blurRadius: 100,
                            spreadRadius: 40,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final showTitle = title.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.paddingXXXL),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 32,
          ),
          child: child,
        ),
      ],
    );
  }
}

class _MobileLoginShell extends StatelessWidget {
  const _MobileLoginShell({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.paddingXL, vertical: AppSpacing.paddingXXL),
        child: RepaintBoundary(
          child: _LoginFormCard(
            title: title,
            child: child,
          ),
        ),
      ),
    );
  }
}
