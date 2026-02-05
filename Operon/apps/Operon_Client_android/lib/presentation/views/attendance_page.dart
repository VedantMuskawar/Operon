import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/data/repositories/attendance_repository_impl.dart';
import 'package:dash_mobile/presentation/blocs/attendance/attendance_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/home_sections/attendance_view.dart';
import 'package:dash_mobile/presentation/widgets/modern_page_header.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;

    if (organization == null) {
      return const Scaffold(
        backgroundColor: AuthColors.background,
        body: Center(
          child: Text(
            'No organization selected',
            style: TextStyle(color: AuthColors.textMain),
          ),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<AttendanceCubit>(
          create: (context) {
            final employeesDataSource = EmployeesDataSource();
            final attendanceDataSource = EmployeeAttendanceDataSource();
            final repository = AttendanceRepositoryImpl(
              employeesDataSource: employeesDataSource,
              attendanceDataSource: attendanceDataSource,
            );
            return AttendanceCubit(
              repository: repository,
              organizationId: organization.id,
            )..loadAttendanceForCurrentMonth();
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AuthColors.background,
        appBar: const ModernPageHeader(
          title: 'Attendance',
        ),
        body: SafeArea(
          child: Stack(
            children: [
              const AttendanceView(),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FloatingNavBar(
                  items: const [
                    NavBarItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      heroTag: 'nav_home',
                    ),
                    NavBarItem(
                      icon: Icons.pending_actions_rounded,
                      label: 'Pending',
                      heroTag: 'nav_pending',
                    ),
                    NavBarItem(
                      icon: Icons.schedule_rounded,
                      label: 'Schedule',
                      heroTag: 'nav_schedule',
                    ),
                    NavBarItem(
                      icon: Icons.map_rounded,
                      label: 'Map',
                      heroTag: 'nav_map',
                    ),
                    NavBarItem(
                      icon: Icons.event_available_rounded,
                      label: 'Cash Ledger',
                      heroTag: 'nav_cash_ledger',
                    ),
                  ],
                  currentIndex: -1,
                  onItemTapped: (value) => context.go('/home', extra: value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
