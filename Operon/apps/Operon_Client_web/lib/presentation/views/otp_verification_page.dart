import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/org_context_persistence_service.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/login_page.dart';
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
  String _otpCode = '';
  int _resendCountdown = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  void _startResendCountdown() {
    _resendCountdown = 60;
    _updateCountdown();
  }

  void _updateCountdown() {
    if (_resendCountdown > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _resendCountdown--;
          });
          _updateCountdown();
        }
      });
    }
  }

  void _handleResendOtp(BuildContext context) {
    final authBloc = context.read<AuthBloc>();
    final phoneNumber = widget.phoneNumber;
    authBloc.add(PhoneNumberSubmitted(phoneNumber));
    _startResendCountdown();
    setState(() {
      _otpCode = '';
      _hasError = false;
    });
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
          final hasError = state.status == ViewStatus.failure && state.errorMessage != null;
          
          // Update error state
          if (hasError != _hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _hasError = hasError);
              }
            });
          }

          // Auto-submit when code is complete
          if (_otpCode.length == 6 && state.status != ViewStatus.loading) {
            final verificationId = state.session?.verificationId;
            if (verificationId != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.read<AuthBloc>().add(
                      OtpSubmitted(
                        verificationId: verificationId,
                        code: _otpCode,
                      ),
                    );
              });
            }
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AnimatedFade(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedFade(
                      delay: const Duration(milliseconds: 100),
                      child: Text(
                        'Enter verification code',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedFade(
                      delay: const Duration(milliseconds: 150),
                      child: Text(
                        'Sent to ${widget.phoneNumber}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 32),
                    AnimatedFade(
                      delay: const Duration(milliseconds: 200),
                      child: Card(
                        color: const Color(0xFF171721),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OtpInputField(
                                length: 6,
                                autoFocus: true,
                                enabled: state.status != ViewStatus.loading,
                                hasError: _hasError,
                                onChanged: (code) {
                                  setState(() {
                                    _otpCode = code;
                                    _hasError = false;
                                  });
                                },
                                onCompleted: (code) {
                                  final verificationId = state.session?.verificationId;
                                  if (verificationId != null) {
                                    context.read<AuthBloc>().add(
                                          OtpSubmitted(
                                            verificationId: verificationId,
                                            code: code,
                                          ),
                                        );
                                  }
                                },
                              ),
                              if (state.status == ViewStatus.loading) ...[
                                const SizedBox(height: 16),
                                const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ],
                              if (hasError && state.errorMessage != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          state.errorMessage!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedFade(
                      delay: const Duration(milliseconds: 250),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Didn't receive code?",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_resendCountdown > 0)
                            Text(
                              'Resend in $_resendCountdown',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white38,
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () => _handleResendOtp(context),
                              child: const Text('Resend code'),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedFade(
                      delay: const Duration(milliseconds: 300),
                      child: Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: const Text('Change number'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
