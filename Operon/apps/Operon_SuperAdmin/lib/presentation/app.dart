import 'package:dash_superadmin/config/app_router.dart';
import 'package:dash_superadmin/config/app_theme.dart';
import 'package:dash_superadmin/data/datasources/firestore_user_checker.dart';
import 'package:dash_superadmin/data/datasources/organization_remote_data_source.dart';
import 'package:dash_superadmin/data/repositories/auth_repository.dart';
import 'package:dash_superadmin/data/repositories/organization_repository.dart';
import 'package:dash_superadmin/domain/usecases/register_organization_with_admin.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashSuperAdminApp extends StatelessWidget {
  const DashSuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();
    final userChecker = FirestoreUserChecker(firestore: authRepository.firestore);
    final organizationRepository = OrganizationRepository(
      remoteDataSource:
          OrganizationRemoteDataSource(firestore: authRepository.firestore),
    );
    final registerOrganizationUseCase = RegisterOrganizationWithAdminUseCase(
      repository: organizationRepository,
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: userChecker),
        RepositoryProvider.value(value: organizationRepository),
        RepositoryProvider.value(value: registerOrganizationUseCase),
      ],
      child: BlocProvider(
        create: (_) => AuthBloc(
          authRepository: authRepository,
          userChecker: userChecker,
        )..add(const AuthStatusRequested()),
        child: MaterialApp.router(
          title: 'Dash SuperAdmin',
          routerConfig: buildRouter(),
          theme: buildDashTheme(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
