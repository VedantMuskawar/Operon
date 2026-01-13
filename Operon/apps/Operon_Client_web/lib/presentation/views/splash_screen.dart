import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger initialization when splash screen is shown
    // This handles both initial app load and post-authentication navigation
    // Also check auth status first to ensure AuthBloc has the current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // First, check auth status to restore user profile in AuthBloc
        context.read<AuthBloc>().add(const AuthStatusRequested());
        // Initialize immediately - AppInitializationCubit will handle auth state
        // The small delay is removed as it's not necessary - the cubit can check auth state directly
        if (context.mounted) {
          context.read<AppInitializationCubit>().initialize();
        }
      }
    });

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
        backgroundColor: AuthColors.backgroundAlt,
        body: Stack(
          children: [
            // Dot grid pattern background - fills entire viewport
            Positioned.fill(
              child: RepaintBoundary(
                child: const DotGridPattern(),
              ),
            ),
            // Main content
            Center(
              child: BlocBuilder<AppInitializationCubit, AppInitializationState>(
                builder: (context, state) {
                  String message = getSplashMessage(state.status);
                  
                  if (state.status == AppInitializationStatus.error) {
                      message = 'Error: ${state.errorMessage ?? "Unknown error"}';
                  }

                  return SplashContent(
                    message: message,
                    showRetry: state.status == AppInitializationStatus.error,
                    onRetry: state.status == AppInitializationStatus.error
                        ? () {
                              context.read<AppInitializationCubit>().retry();
                          }
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
