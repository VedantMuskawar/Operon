import 'package:flutter/material.dart';

class LoginPageShell extends StatelessWidget {
  const LoginPageShell({
    super.key,
    required this.child,
    this.title = '',
  });

  final Widget child;
  final String title;

  static const _outerBackground = Color(0xFF020205);
  static const _panelColor = Color(0xFF0B0B12);
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
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 720),
                decoration: BoxDecoration(
                  color: _panelColor,
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 70,
                      offset: Offset(0, 35),
                    ),
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 30,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
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
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(48),
          bottomLeft: Radius.circular(48),
        ),
        gradient: LinearGradient(
          colors: [Color(0xFF0E0E17), Color(0xFF08080F)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
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
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

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
        child: Stack(
          children: [
            Positioned(
              top: 120,
              right: 140,
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
          ],
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

  static const _dividerColor = Color(0x1AFFFFFF);

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
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF11111D),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _dividerColor),
            boxShadow: const [
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 20,
                offset: Offset(0, 12),
              ),
            ],
          ),
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
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0B0B12),
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 60,
                offset: Offset(0, 30),
              ),
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 200,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF9F7BFF),
                              Color(0xFF6F4BFF),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.blur_on,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Dash Mobile',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _LoginFormCard(
                  title: title,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

