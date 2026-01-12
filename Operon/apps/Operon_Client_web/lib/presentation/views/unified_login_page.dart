import 'dart:async';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/org_context_persistence_service.dart';
import 'package:dash_web/data/services/phone_persistence_service.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/views/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

enum _LoginState { phone, otp }

class _UnifiedLoginPageState extends State<UnifiedLoginPage>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  _LoginState _currentState = _LoginState.phone;
  int _resendCountdown = 0;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoadingSavedPhone = true;
  Timer? _resendTimer;
  late AnimationController _transitionController;

  // Cache expensive color computations
  static const _primaryColor = Color(0xFF5D1C19);

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _phoneController.addListener(() {
      setState(() {});
    });
    _loadSavedPhoneNumber();
  }

  Future<void> _loadSavedPhoneNumber() async {
    final savedPhone = await PhonePersistenceService.loadPhoneNumber();
    if (savedPhone != null && savedPhone.isNotEmpty) {
      final digits = savedPhone.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 10) {
        final phoneDigits = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
        _phoneController.text = phoneDigits;
      }
    }
    if (mounted) {
      setState(() => _isLoadingSavedPhone = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _resendTimer?.cancel();
    _transitionController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendCountdown = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCountdown <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _resendCountdown--);
    });
  }

  void _handleResendOtp(BuildContext context, String phoneNumber) {
    context.read<AuthBloc>().add(PhoneNumberSubmitted(phoneNumber));
    _startResendCountdown();
    setState(() {
      _otpController.clear();
      _hasError = false;
      _errorMessage = null;
    });
  }

  String _parseErrorMessage(String? rawError) {
    if (rawError == null) return 'Verification failed. Please try again.';
    
    final error = rawError.toLowerCase();
    
    // Handle specific Firebase error codes
    if (error.contains('invalid-verification-code') || 
        error.contains('invalid verification code')) {
      return 'Invalid code. Please check and try again.';
    }
    if (error.contains('session-expired') || 
        error.contains('expired')) {
      return 'Code expired. Please request a new one.';
    }
    if (error.contains('code-expired')) {
      return 'This code has expired. Please request a new one.';
    }
    if (error.contains('too-many-requests') || 
        error.contains('too many attempts')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (error.contains('network') || 
        error.contains('connection') ||
        error.contains('timeout')) {
      return 'Network error. Please check your connection and try again.';
    }
    if (error.contains('quota-exceeded')) {
      return 'SMS quota exceeded. Please try again later.';
    }
    
    // Return user-friendly message or original if already friendly
    if (rawError.length > 100) {
      return 'Verification failed. Please try again.';
    }
    return rawError;
  }

  void _handleChangeNumber(BuildContext context) {
    context.read<AuthBloc>().add(const AuthReset());
    setState(() {
      _otpController.clear();
      _hasError = false;
      _resendCountdown = 0;
      _currentState = _LoginState.phone;
    });
    _resendTimer?.cancel();
    _transitionController.reverse();
  }

  void _handlePhoneSubmit(BuildContext context) {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      DashSnackbar.show(
        context,
        message: 'Please enter a valid 10-digit number',
        isError: true,
      );
      return;
    }
    final formattedNumber = '+91$digits';
    context.read<AuthBloc>().add(PhoneNumberSubmitted(formattedNumber));
    setState(() {
      _currentState = _LoginState.otp;
    });
    _transitionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return LoginPageShell(
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          // Handle OTP verification errors
          if (state.status == ViewStatus.failure && state.errorMessage != null) {
            if (_currentState == _LoginState.otp) {
              // OTP verification error - clear OTP and show error
              setState(() {
                _otpController.clear();
                _hasError = true;
                _errorMessage = _parseErrorMessage(state.errorMessage);
              });
              
              // Clear OTP field visually
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {});
                }
              });
            } else {
              // Phone submission error - show snackbar
              DashSnackbar.show(
                context, 
                message: _parseErrorMessage(state.errorMessage),
                isError: true,
              );
            }
          }
          
          if (state.status == ViewStatus.success && state.session != null) {
            if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) {
              await PhonePersistenceService.savePhoneNumber(state.phoneNumber!);
            }
            _startResendCountdown();
            // Clear any previous errors when OTP is sent successfully
            setState(() {
              _hasError = false;
              _errorMessage = null;
            });
          }
          
          if (state.userProfile != null && state.status == ViewStatus.success) {
            final userId = state.userProfile!.id;
            final savedContext = await OrgContextPersistenceService.loadContext();
            
            if (savedContext != null && savedContext.userId != userId) {
              await OrgContextPersistenceService.clearContext();
              if (context.mounted) {
                await context.read<OrganizationContextCubit>().clear();
              }
            }
            
            if (context.mounted) {
              context.read<AppInitializationCubit>().initialize();
              context.go('/splash');
            }
          }
        },
        buildWhen: (previous, current) {
          return previous.session != current.session ||
                 previous.status != current.status ||
                 previous.phoneNumber != current.phoneNumber;
        },
        builder: (context, state) {
          final phoneNumber = state.phoneNumber ?? '';


          if (_isLoadingSavedPhone) {
            return _buildLoadingState();
          }

          return Stack(
            children: [
              // Dot grid pattern background - fills entire viewport
              Positioned.fill(
                child: const DotGridPattern(),
              ),
              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Transform.translate(
                    offset: const Offset(0, -20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Sign In header
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontFamily: 'SF Pro Display',
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 40),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 450),
                          child: _buildLoginCard(context, state, phoneNumber),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_primaryColor, Color(0xFF8F6BFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildLoginCard(BuildContext context, AuthState state, String phoneNumber) {
    final isOtpState = _currentState == _LoginState.otp;
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF871C1C).withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular gradient dots
            _buildCircularGradientDots(),
            const SizedBox(height: 32),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeInOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: (child, animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: isOtpState 
                        ? const Offset(1.0, 0)  // OTP slides in from right
                        : const Offset(-1.0, 0), // Phone slides out to left
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOutCubic,
                  )),
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: isOtpState
                  ? _buildOtpView(context, state, phoneNumber)
                  : _buildPhoneView(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneView(BuildContext context, AuthState state) {
    final hasText = _phoneController.text.isNotEmpty;
    
    return Column(
      key: const ValueKey('phone'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF871C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    fontFamily: 'SF Pro Display',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone Number',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 17,
                      fontFamily: 'SF Pro Display',
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: hasText
                    ? Container(
                        key: const ValueKey('arrow'),
                        margin: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: state.status == ViewStatus.loading
                                ? null
                                : () => _handlePhoneSubmit(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                color: state.status == ViewStatus.loading
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), width: 0),
              ),
            ],
          ),
        ),
        if (state.status == ViewStatus.loading) ...[
          const SizedBox(height: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtpView(BuildContext context, AuthState state, String phoneNumber) {
    return Column(
      key: const ValueKey('otp'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _handleChangeNumber(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'We sent a 6-digit code to\n$phoneNumber',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  fontFamily: 'SF Pro Display',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF871C1C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasError
                  ? Colors.red.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: _otpController,
            enabled: state.status != ViewStatus.loading,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
              letterSpacing: 12,
              fontFamily: 'SF Pro Display',
            ),
            decoration: InputDecoration(
              hintText: '000000',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: 12,
                fontFamily: 'SF Pro Display',
              ),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onChanged: (value) {
              setState(() {
                if (_hasError && value.isNotEmpty) {
                  _hasError = false;
                  _errorMessage = null;
                }
              });
              // Auto-submit when 6 digits are entered
              if (value.length == 6 && !_hasError) {
                final verificationId = state.session?.verificationId;
                if (verificationId != null) {
                  context.read<AuthBloc>().add(
                        OtpSubmitted(
                          verificationId: verificationId,
                          code: value,
                        ),
                      );
                }
              }
            },
          ),
        ),
        if (state.status == ViewStatus.loading) ...[
          const SizedBox(height: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
        if (_hasError && _errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 13,
              fontFamily: 'SF Pro Display',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive code?",
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(width: 8),
            if (_resendCountdown > 0)
              Text(
                'Resend in $_resendCountdown',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                  fontFamily: 'SF Pro Display',
                ),
              )
            else
              TextButton(
                onPressed: () => _handleResendOtp(context, phoneNumber),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'SF Pro Display',
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularGradientDots() {
    return ICloudDottedCircle(
      size: 200,
    );
  }

}
