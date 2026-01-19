import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/datasources/employees_data_source.dart';
import 'package:dash_web/data/repositories/attendance_repository_impl.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/presentation/blocs/attendance/attendance_cubit.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/home_sections/attendance_view.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
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
            final employeesRepository = EmployeesRepository(
              dataSource: employeesDataSource,
            );
            final attendanceDataSource = EmployeeAttendanceDataSource();
            final repository = AttendanceRepositoryImpl(
              employeesRepository: employeesRepository,
              attendanceDataSource: attendanceDataSource,
            );
            return AttendanceCubit(
              repository: repository,
              organizationId: organization.id,
            )..loadAttendanceForCurrentMonth();
          },
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Attendance',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const AttendanceView(),
      ),
    );
  }
}
