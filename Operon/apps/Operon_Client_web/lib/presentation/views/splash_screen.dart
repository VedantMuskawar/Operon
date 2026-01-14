import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check current state first - on hot restart, state might already be restored
    final currentState = context.read<AppInitializationCubit>().state;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        // If already restored, navigate immediately
        if (currentState.status == AppInitializationStatus.contextRestored) {
          context.go('/home');
          return;
        }
        
        // If already authenticated and ready, check if we should restore or go to org-selection
        if (currentState.status == AppInitializationStatus.ready ||
            currentState.status == AppInitializationStatus.contextRestoreFailed) {
          // Check if org context is actually set (might have been restored but status not updated)
          final orgState = context.read<OrganizationContextCubit>().state;
          if (orgState.hasSelection) {
            context.go('/home');
            return;
          }
          context.go('/org-selection');
          return;
        }
        
        // If not authenticated, go to login
        if (currentState.status == AppInitializationStatus.notAuthenticated) {
          context.go('/login');
          return;
        }
        
        // Otherwise, trigger initialization
        // First, check auth status to restore user profile in AuthBloc
        context.read<AuthBloc>().add(const AuthStatusRequested());
        // Initialize immediately - AppInitializationCubit will handle auth state
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
          // But first check if org context is actually set
          final orgState = context.read<OrganizationContextCubit>().state;
          if (orgState.hasSelection) {
            context.go('/home');
          } else {
            context.go('/org-selection');
          }
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
