import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppInitializationCubit, AppInitializationState>(
      listener: (context, state) {
        if (state.status == AppInitializationStatus.notAuthenticated) {
          // User is not authenticated, go to login
          context.go('/login');
        } else if (state.status == AppInitializationStatus.contextRestored) {
          // Context restored successfully, go to home
          context.go('/home');
        } else if (state.status == AppInitializationStatus.ready ||
            state.status == AppInitializationStatus.contextRestoreFailed) {
          // Ready but no context, go to org selection
          context.go('/org-selection');
        } else if (state.status == AppInitializationStatus.error) {
          // Show error and allow retry
          // For now, just go to login
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020205),
        body: Center(
          child: BlocBuilder<AppInitializationCubit, AppInitializationState>(
            builder: (context, state) {
              String message = 'Loading...';
              
              switch (state.status) {
                case AppInitializationStatus.checkingAuth:
                  message = 'Checking authentication...';
                  break;
                case AppInitializationStatus.loadingOrganizations:
                  message = 'Loading organizations...';
                  break;
                case AppInitializationStatus.restoringContext:
                  message = 'Restoring session...';
                  break;
                case AppInitializationStatus.error:
                  message = 'Error: ${state.errorMessage ?? "Unknown error"}';
                  break;
                default:
                  message = 'Loading...';
              }

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo or Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6F4BFF), Color(0xFF5A3FE0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.dashboard,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6F4BFF)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  if (state.status == AppInitializationStatus.error) ...[
                    const SizedBox(height: 24),
                    DashButton(
                      label: 'Retry',
                      onPressed: () {
                        context.read<AppInitializationCubit>().retry();
                      },
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

