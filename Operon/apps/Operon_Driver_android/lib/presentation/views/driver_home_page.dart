import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/data/repositories/users_repository.dart';
import 'package:operon_driver_android/presentation/screens/home/driver_home_screen.dart';
import 'package:operon_driver_android/presentation/views/driver_schedule_trips_page.dart';
import 'package:operon_driver_android/presentation/widgets/user_ledger_table.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({super.key});

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  int _currentIndex = 0;
  Future<String>? _employeeNameFuture;
  String? _employeeNameOrgId;
  String? _employeeNameUserId;
  String? _employeeNamePhone;

  void _ensureEmployeeNameFuture({
    required String organizationId,
    required String userId,
    required String phoneNumber,
  }) {
    final changed = _employeeNameFuture == null ||
        _employeeNameOrgId != organizationId ||
        _employeeNameUserId != userId ||
        _employeeNamePhone != phoneNumber;

    if (!changed) return;

    _employeeNameOrgId = organizationId;
    _employeeNameUserId = userId;
    _employeeNamePhone = phoneNumber;
    _employeeNameFuture = _loadEmployeeName(
      organizationId: organizationId,
      userId: userId,
      phoneNumber: phoneNumber,
    );
  }

  Future<String> _loadEmployeeName({
    required String organizationId,
    required String userId,
    required String phoneNumber,
  }) async {
    try {
      final usersRepository = context.read<UsersRepository>();
      final organizationUser = await usersRepository.fetchCurrentUser(
        orgId: organizationId,
        userId: userId,
        phoneNumber: phoneNumber,
      );
      final name = organizationUser?.name.trim() ?? '';
      if (name.isNotEmpty) return name;
    } catch (_) {
      // Fallback below
    }

    final authUser = context.read<AuthBloc>().state.userProfile;
    final displayName = authUser?.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;
    return 'Employee';
  }

  @override
  Widget build(BuildContext context) {
    // Keep watch here so the shell responds to org changes
    // (e.g. name in app bar / schedule tab queries later).
    final orgState = context.watch<OrganizationContextCubit>().state;
    final authState = context.watch<AuthBloc>().state;

    final organizationId = orgState.organization?.id;
    final userId = authState.userProfile?.id;
    final phoneNumber = authState.userProfile?.phoneNumber;
    if (organizationId != null && userId != null && phoneNumber != null) {
      _ensureEmployeeNameFuture(
        organizationId: organizationId,
        userId: userId,
        phoneNumber: phoneNumber,
      );
    }

    return Scaffold(
      backgroundColor: AuthColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.person_outline,
            color: AuthColors.textMain,
          ),
          onPressed: () => context.go('/profile'),
        ),
        title: FutureBuilder<String>(
          future: _employeeNameFuture,
          builder: (context, snapshot) {
            final name = (snapshot.data ?? '').trim();
            return Text(
              name.isEmpty ? 'Employee' : name,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'SF Pro Display',
              ),
            );
          },
        ),
        centerTitle: true,
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
                  _DriverHomeTab(employeeNameFuture: _employeeNameFuture),
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
  const _DriverHomeTab({required this.employeeNameFuture});

  final Future<String>? employeeNameFuture;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: employeeNameFuture,
            builder: (context, snapshot) {
              final name = (snapshot.data ?? '').trim();
              return Text(
                name.isEmpty ? 'Employee' : name,
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 20,
                  fontFamily: 'SF Pro Display',
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const UserLedgerTable(),
        ],
      ),
    );
  }
}
