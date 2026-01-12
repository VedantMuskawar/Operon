import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/phone_persistence_service.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/views/login_page.dart';
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
  bool _isLoadingSavedPhone = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPhoneNumber();
  }

  Future<void> _loadSavedPhoneNumber() async {
    final savedPhone = await PhonePersistenceService.loadPhoneNumber();
    if (savedPhone != null && savedPhone.isNotEmpty) {
      // Remove country code (+91) if present to show only the 10-digit number
      final digits = savedPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final phoneDigits = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
        _controller.text = phoneDigits;
      }
    }
    if (mounted) {
      setState(() => _isLoadingSavedPhone = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
          if (state.status == ViewStatus.success && state.session != null) {
            // Save phone number when OTP is sent successfully
            if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) {
              await PhonePersistenceService.savePhoneNumber(state.phoneNumber!);
            }
            context.push('/otp?phone=${Uri.encodeComponent(state.phoneNumber ?? '')}');
          }
        },
        builder: (context, state) {
          final theme = Theme.of(context);
          
          // Show loading while loading saved phone
          if (_isLoadingSavedPhone) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonFormField(),
                  const SizedBox(height: 24),
                  SkeletonButton(),
                ],
              ),
            );
          }
          
          return AnimatedFade(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedFade(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    'Login',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedFade(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    'Enter your work number to receive a one-time code.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                AnimatedFade(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    colors: [Color(0x251E1E2D), Color(0x33151520)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFF6F4BFF).withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phone number', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6F4BFF).withOpacity(0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 70,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(16),
                              ),
                            ),
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
                            color: Colors.white12,
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: TextFormField(
                                controller: _controller,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                decoration: InputDecoration(
                                  hintText: '10-digit number',
                                  hintStyle: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.45),
                                  ),
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    DashButton(
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
                  ],
                ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
