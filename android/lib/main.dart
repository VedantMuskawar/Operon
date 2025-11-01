import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'core/config/android_config.dart';
import 'core/services/android_auth_repository.dart';
import 'features/auth/android_auth_bloc.dart';
import 'features/auth/presentation/pages/android_login_page.dart';
import 'features/organization/presentation/bloc/android_organization_bloc.dart';
import 'features/organization/presentation/pages/android_organization_select_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase only if not already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized, continue
    print('Firebase already initialized: $e');
  }
  
  runApp(const OperonAndroidApp());
}

class OperonAndroidApp extends StatelessWidget {
  const OperonAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AndroidAuthRepository>(
          create: (context) => AndroidAuthRepository(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AndroidAuthBloc>(
            create: (context) => AndroidAuthBloc(
              authRepository: context.read<AndroidAuthRepository>(),
            )..add(AndroidAuthCheckRequested()),
          ),
          BlocProvider<AndroidOrganizationBloc>(
            create: (context) => AndroidOrganizationBloc(
              authRepository: context.read<AndroidAuthRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: AndroidConfig.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: BlocBuilder<AndroidAuthBloc, AndroidAuthState>(
            builder: (context, state) {
              if (state is AndroidAuthAuthenticated) {
                // Show organization selector for authenticated users
                return AndroidOrganizationSelectPage(
                  firebaseUser: state.firebaseUser,
                );
              }
              return const AndroidLoginPage();
            },
          ),
        ),
      ),
    );
  }
}