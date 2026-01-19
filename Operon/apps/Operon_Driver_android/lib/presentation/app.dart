import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/config/app_router.dart';
import 'package:operon_driver_android/config/app_theme.dart';

class OperonDriverApp extends StatelessWidget {
  const OperonDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();
    final scheduledTripsRepository = ScheduledTripsRepository(
      dataSource: ScheduledTripsDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final organizationRepository = UserOrganizationRepository(
      dataSource: UserOrganizationDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final appAccessRolesRepository = AppAccessRolesRepository(
      dataSource: AppAccessRolesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final router = buildRouter();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: organizationRepository),
        RepositoryProvider.value(value: appAccessRolesRepository),
        RepositoryProvider.value(value: scheduledTripsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              authRepository: authRepository,
            )..add(const AuthStatusRequested()),
          ),
          BlocProvider(create: (_) => OrganizationContextCubit()),
          BlocProvider(
            create: (_) => OrgSelectorCubit(
              repository: organizationRepository,
            ),
          ),
          BlocProvider(
            lazy: false,
            create: (context) => AppInitializationCubit(
              authRepository: authRepository,
              orgContextCubit: context.read<OrganizationContextCubit>(),
              orgSelectorCubit: context.read<OrgSelectorCubit>(),
              appAccessRolesRepository: appAccessRolesRepository,
            ),
          ),
        ],
        child: MaterialApp.router(
          title: 'Operon Driver',
          theme: buildOperonDriverTheme(),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

