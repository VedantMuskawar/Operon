import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/app_theme.dart';
import 'core/config/android_config.dart';
import 'core/services/android_auth_repository.dart';
import 'core/services/call_detection_service.dart';
import 'core/services/firestore_bootstrap.dart';
import 'core/utils/overlay_manager.dart';
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
  
  // Configure Firestore caches/telemetry before rendering the app.
  await FirestoreBootstrap.ensureInitialized();

  // Initialize call detection service
  final callDetectionService = CallDetectionService.instance;
  callDetectionService.onIncomingCall = (orderInfo) {
    print('main.dart: onIncomingCall callback triggered - phoneNumber: ${orderInfo.phoneNumber}');
    OverlayManager.instance.showOverlay(orderInfo);
  };
  callDetectionService.onCallOffhook = () {
    // Keep overlay visible during call
    print('main.dart: onCallOffhook callback triggered');
  };
  callDetectionService.onCallEnded = () {
    print('main.dart: onCallEnded callback triggered');
    OverlayManager.instance.hideOverlay();
  };
  
  print('main.dart: Call detection service initialized');
  
  runApp(const OperonAndroidApp());
}

class OperonAndroidApp extends StatelessWidget {
  const OperonAndroidApp({super.key});

  // Navigator key for overlay management
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
        child: Builder(
          builder: (context) {
            return MaterialApp(
              title: AndroidConfig.appTitle,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.darkTheme,
              navigatorKey: OperonAndroidApp.navigatorKey,
              builder: (context, child) {
                // Set navigator key after MaterialApp is built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  try {
                    OverlayManager.instance.setNavigatorKey(OperonAndroidApp.navigatorKey);
                    print('main.dart: Navigator key set in postFrameCallback');
                  } catch (e) {
                    print('Error setting navigator key: $e');
                  }
                });
                return child ?? const SizedBox.shrink();
              },
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
            );
          },
        ),
      ),
    );
  }
}