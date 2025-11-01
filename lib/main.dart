import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/organization/presentation/pages/organization_select_page.dart';
import 'contexts/organization_context.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const OperonApp());
}

class OperonApp extends StatelessWidget {
  const OperonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (context) => AuthRepository(),
        ),
      ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>(
              create: (context) => AuthBloc(
                authRepository: context.read<AuthRepository>(),
              )..add(AuthCheckRequested()),
            ),
          ],
        child: OrganizationProvider(
          child: MaterialApp(
            title: 'OPERON',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthOrganizationSelectionRequired) {
                  return const OrganizationSelectPage();
                } else if (state is AuthAuthenticated) {
                  // This should not happen in normal flow, but handle it gracefully
                  return const LoginPage();
                }
                return const LoginPage();
              },
            ),
          ),
        ),
      ),
    );
  }
}
