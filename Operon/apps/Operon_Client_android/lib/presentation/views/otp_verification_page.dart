import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/org_context_persistence_service.dart';
import 'package:dash_mobile/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/views/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class OtpVerificationPage extends StatefulWidget {
  const OtpVerificationPage({super.key, required this.phoneNumber});

  final String phoneNumber;

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LoginPageShell(
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          if (state.status == ViewStatus.failure && state.errorMessage != null) {
            DashSnackbar.show(context, message: state.errorMessage!, isError: true);
          }
          // Only navigate if we have a user profile AND the status is success
          // This prevents navigation during error states
          if (state.userProfile != null && state.status == ViewStatus.success) {
            // Clear any existing context for different user
            final userId = state.userProfile!.id;
            final savedContext = await OrgContextPersistenceService.loadContext();
            
            if (savedContext != null && savedContext.userId != userId) {
              await OrgContextPersistenceService.clearContext();
              if (context.mounted) {
                await context.read<OrganizationContextCubit>().clear();
              }
            }
            
            // Re-initialize app to load organizations and restore context if available
            if (context.mounted) {
              context.read<AppInitializationCubit>().initialize();
              context.go('/splash');
            }
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter verification code',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sent to ${widget.phoneNumber}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    color: const Color(0xFF171721),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DashFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            label: '6-digit code',
                          ),
                          const SizedBox(height: 16),
                          DashButton(
                            label: 'Verify',
                            isLoading: state.status == ViewStatus.loading,
                            onPressed: () {
                              final code = _codeController.text.trim();
                              final verificationId = state.session?.verificationId;
                              if (code.length < 4 || verificationId == null) {
                                DashSnackbar.show(
                                  context,
                                  message: 'Invalid code or session. Please request OTP again.',
                                  isError: true,
                                );
                                return;
                              }
                              context.read<AuthBloc>().add(
                                    OtpSubmitted(
                                      verificationId: verificationId,
                                      code: code,
                                    ),
                                  );
                            },
                          ),
                          const SizedBox(height: 12),
                          _DebugPanel(state: state),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Change number'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DebugPanel extends StatelessWidget {
  const _DebugPanel({required this.state});

  final AuthState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logs = state.logs;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.04),
      ),
      padding: const EdgeInsets.all(12),
      child: DefaultTextStyle(
        style: theme.textTheme.labelSmall!.copyWith(color: Colors.white70),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status: ${state.status.name}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text('Session: ${state.session?.verificationId ?? "none"}'),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text('Error: ${state.errorMessage}', style: const TextStyle(color: Colors.redAccent)),
            ],
            if (logs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Logs:', style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              ...logs.take(6).map((e) => Text('• $e')),
            ],
          ],
        ),
      ),
    );
  }
}

