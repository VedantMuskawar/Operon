import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/views/login_page.dart';
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
        listener: (context, state) {
          if (state.status == ViewStatus.failure && state.errorMessage != null) {
            DashSnackbar.show(context, message: state.errorMessage!, isError: true);
          }
          if (state.userProfile != null) {
            context.go('/dashboard');
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 24),
              DashFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                label: '6-digit code',
              ),
              const SizedBox(height: 24),
              DashButton(
                label: 'Verify',
                isLoading: state.status == ViewStatus.loading,
                onPressed: () {
                  final code = _codeController.text.trim();
                  final verificationId = state.session?.verificationId;
                  if (code.length < 4 || verificationId == null) {
                    DashSnackbar.show(
                      context,
                      message: 'Invalid code. Please try again.',
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
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Change number'),
              ),
            ],
          );
        },
      ),
    );
  }
}
