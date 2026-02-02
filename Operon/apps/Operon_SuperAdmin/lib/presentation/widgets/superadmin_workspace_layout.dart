import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Workspace-style layout for SuperAdmin dashboard.
/// Matches Client Web: DotGridPattern background, left sidebar, content area.
class SuperAdminWorkspaceLayout extends StatelessWidget {
  const SuperAdminWorkspaceLayout({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
  });

  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onNavTap;

  static const _sectionLabels = ['Overview', 'Organizations'];

  @override
  Widget build(BuildContext context) {
    final sidebarItems = [
      DashSidebarItem(
        icon: Icons.dashboard_outlined,
        label: _sectionLabels[0],
        onTap: () => onNavTap(0),
        isActive: currentIndex == 0,
      ),
      DashSidebarItem(
        icon: Icons.apartment_rounded,
        label: _sectionLabels[1],
        onTap: () => onNavTap(1),
        isActive: currentIndex == 1,
      ),
    ];

    return Scaffold(
      backgroundColor: AuthColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: DotGridPattern(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DashSidebar(
                  items: sidebarItems,
                  logo: _SidebarLogo(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        displayName:
                            context.watch<AuthBloc>().state.userProfile?.displayName ??
                                'Super Admin',
                        onSignOut: () =>
                            context.read<AuthBloc>().add(const AuthReset()),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: RepaintBoundary(
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          'assets/branding/operon_app_icon.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 12),
        Text(
          'Operon Super Admin',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AuthColors.textMain,
              ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.displayName,
    required this.onSignOut,
  });

  final String displayName;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            'Control Center',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuthColors.textMain,
                ),
          ),
          const Spacer(),
          Text(
            'Signed in as $displayName',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuthColors.textSub,
                ),
          ),
          const SizedBox(width: 16),
          DashButton(
            label: 'Sign out',
            icon: Icons.logout_sharp,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}
