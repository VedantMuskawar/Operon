import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/views/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PhoneInputPage extends StatefulWidget {
  const PhoneInputPage({super.key});

  @override
  State<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends State<PhoneInputPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
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
          if (state.status == ViewStatus.success && state.session != null) {
            context.push('/otp?phone=${Uri.encodeComponent(state.phoneNumber ?? '')}');
          }
          if (state.userProfile != null) {
            context.go('/dashboard');
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Login',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Text('Phone number', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 255, 255, 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF836DFF).withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 56,
                      alignment: Alignment.center,
                      child: const Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color.fromRGBO(255, 255, 255, 0.1),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: TextFormField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.left,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Enter your 10-digit number',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            filled: false,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 400,
                child: DashButton(
                  label: 'Send OTP',
                  isLoading: state.status == ViewStatus.loading,
                  onPressed: () {
                    final digits =
                        _controller.text.replaceAll(RegExp(r'\D'), '');
                    if (digits.length != 10) {
                      DashSnackbar.show(
                        context,
                        message: 'Enter a valid 10-digit number',
                        isError: true,
                      );
                      return;
                    }
                    final formattedNumber = '+91$digits';
                    context
                        .read<AuthBloc>()
                        .add(PhoneNumberSubmitted(formattedNumber));
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
