import 'package:dash_mobile/presentation/widgets/quick_nav_bar.dart';
import 'package:flutter/material.dart';

class PageWorkspaceLayout extends StatelessWidget {
  const PageWorkspaceLayout({
    super.key,
    required this.title,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
    this.onBack,
    this.hideTitle = false,
  });

  final String title;
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onNavTap;
  final VoidCallback? onBack;
  final bool hideTitle;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final statusBar = media.padding.top;
    final bottomSafe = media.padding.bottom;
    final totalHeight = media.size.height;
    const headerHeight = 72.0;
    final navArea = bottomSafe + 80;
    final rawHeight = totalHeight - statusBar - headerHeight - navArea - 24;
    final panelHeight = rawHeight.clamp(320, totalHeight).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF010104),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    if (!hideTitle)
                    Row(
                      children: [
                        IconButton(
                          onPressed: onBack ??
                              () {
                                Navigator.of(context).maybePop();
                              },
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white70),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 48), // balance for icon button
                      ],
                      )
                    else
                      Row(
                        children: [
                          IconButton(
                            onPressed: onBack ??
                                () {
                                  Navigator.of(context).maybePop();
                                },
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Colors.white70),
                          ),
                        ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        height: panelHeight,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1F1F33), Color(0xFF0F0F16)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 45,
                              offset: Offset(0, 25),
                            ),
                          ],
                          border: Border.all(color: Colors.white10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: child,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: navArea - bottomSafe),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: QuickNavBar(
                currentIndex: currentIndex,
                onTap: onNavTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

