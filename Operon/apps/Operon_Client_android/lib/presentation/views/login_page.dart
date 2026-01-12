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

  static const _outerBackground = Color(0xFF000000);
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
        topRight: Radius.circular(48),
        bottomRight: Radius.circular(48),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF080816),
              Color(0xFF0C0C1F),
              Color(0xFF120F25),
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
                        borderRadius: BorderRadius.circular(48),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0x332E1BFF),
                            Color(0x003C1DA6),
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40836DFF),
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
          const SizedBox(height: 32),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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

