import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/presentation/screens/home/driver_home_screen.dart';
import 'package:operon_driver_android/presentation/views/driver_schedule_trips_page.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Keep watch here so the shell responds to org changes
    // (e.g. name in app bar / schedule tab queries later).
    context.watch<OrganizationContextCubit>().state;

    return Scaffold(
      backgroundColor: AuthColors.background,
      drawer: const _DriverProfileDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(
              Icons.person_outline,
              color: AuthColors.textMain,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const SizedBox.shrink(),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: DotGridPattern(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              // Space for floating bottom nav pill.
              padding: const EdgeInsets.only(bottom: 96),
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  const _DriverHomeTab(),
                  const DriverScheduleTripsPage(),
                  const DriverHomeScreen(),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingNavBar(
              items: const [
                NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  heroTag: 'driver_nav_home',
                ),
                NavBarItem(
                  icon: Icons.schedule_rounded,
                  label: 'Schedule',
                  heroTag: 'driver_nav_schedule',
                ),
                NavBarItem(
                  icon: Icons.map_rounded,
                  label: 'Map',
                  heroTag: 'driver_nav_map',
                ),
              ],
              currentIndex: _currentIndex,
              onItemTapped: (index) {
                if (index == _currentIndex) return;
                setState(() => _currentIndex = index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverHomeTab extends StatelessWidget {
  const _DriverHomeTab();

  @override
  Widget build(BuildContext context) {
    // Home stays intentionally minimal for now (tiles will come later).
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Home',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontFamily: 'SF Pro Display',
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Profile is available from the top-left icon.',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 14,
                fontFamily: 'SF Pro Display',
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DriverProfileDrawer extends StatelessWidget {
  const _DriverProfileDrawer();

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final orgState = context.read<OrganizationContextCubit>().state;

    return Drawer(
      backgroundColor: AuthColors.surface,
      child: ProfileView(
        user: authState.userProfile,
        organization: orgState.organization,
        onChangeOrg: () async {
          Navigator.of(context).pop(); // close drawer
          await context.read<OrganizationContextCubit>().clear();
          if (!context.mounted) return;
          context.go('/org-selection');
        },
        onLogout: () async {
          Navigator.of(context).pop(); // close drawer
          await context.read<OrganizationContextCubit>().clear();
          if (!context.mounted) return;
          context.read<AuthBloc>().add(const AuthReset());
          context.go('/login');
        },
        // Driver app doesn’t expose admin pages (users/permissions) right now.
        onOpenUsers: null,
        onOpenPermissions: null,
      ),
    );
  }
}

