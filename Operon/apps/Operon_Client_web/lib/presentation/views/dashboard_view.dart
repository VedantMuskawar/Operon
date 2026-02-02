import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class WebDashboardView extends StatelessWidget {
  const WebDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveScaffold(
      mobile: _MobileDashboard(),
      desktop: _DesktopDashboard(),
    );
  }
}

class _MobileDashboard extends StatelessWidget {
  const _MobileDashboard();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Mobile layout fallback')),
    );
  }
}

class _DesktopDashboard extends StatelessWidget {
  const _DesktopDashboard();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: DashSidebar(
                  items: [
                    DashSidebarItem(
                      icon: Icons.dashboard,
                      label: 'Dashboard',
                      onTap: () {},
                      isActive: true,
                    ),
                    DashSidebarItem(
                      icon: Icons.people_alt,
                      label: 'Users',
                      onTap: () {},
                    ),
                  ],
                  logo: SizedBox(
                    width: 232,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/branding/operon_app_icon.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_not_supported_outlined,
                            size: 36,
                            color: AuthColors.textMain,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Operon',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AuthColors.textMain,
                                ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashAppBar(
                      title: Text(
                        'Welcome back, Admin',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      actions: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        children: const [
                          DashCard(child: Text('Metric 1')),
                          DashCard(child: Text('Metric 2')),
                          DashCard(child: Text('Metric 3')),
                          DashCard(child: Text('Metric 4')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
