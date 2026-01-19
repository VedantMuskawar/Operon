import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/src/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:operon_auth_flow/src/blocs/auth/auth_bloc.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger initialization when splash screen is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        context.read<AuthBloc>().add(const AuthStatusRequested());
        if (context.mounted) {
          context.read<AppInitializationCubit>().initialize();
        }
      }
    });

    return BlocListener<AppInitializationCubit, AppInitializationState>(
      listener: (context, state) {
        if (state.status == AppInitializationStatus.notAuthenticated) {
          context.go('/login');
        } else if (state.status == AppInitializationStatus.contextRestored) {
          context.go('/home');
        } else if (state.status == AppInitializationStatus.ready ||
            state.status == AppInitializationStatus.contextRestoreFailed) {
          context.go('/org-selection');
        } else if (state.status == AppInitializationStatus.error) {
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: AuthColors.backgroundAlt,
        body: Stack(
          children: [
            const Positioned.fill(
              child: RepaintBoundary(
                child: DotGridPattern(),
              ),
            ),
            Center(
              child: BlocBuilder<AppInitializationCubit, AppInitializationState>(
                builder: (context, state) {
                  var message = getSplashMessage(state.status);

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

