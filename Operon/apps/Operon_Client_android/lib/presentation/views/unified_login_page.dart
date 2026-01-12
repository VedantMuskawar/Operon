import 'dart:async';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/org_context_persistence_service.dart';
import 'package:dash_mobile/data/services/phone_persistence_service.dart';
import 'package:dash_mobile/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  int _resendCountdown = 0;
  bool _hasError = false;
  String? _errorMessage;
  bool _isLoadingSavedPhone = true;
  Timer? _resendTimer;

  // Cache expensive color computations
  static const _primaryColor = Color(0xFF5D1C19);

  @override
  void initState() {
    super.initState();
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
    });
    _resendTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      body: Stack(
        children: [
          // Dot grid pattern background - fills entire viewport
          const Positioned.fill(
            child: DotGridPattern(),
          ),
          // Main content
          Container(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          // Handle OTP verification errors
          if (state.status == ViewStatus.failure && state.errorMessage != null) {
            final showOtp = state.session != null;
            
            if (showOtp) {
              // OTP verification error - clear OTP and show error
              setState(() {
                _otpController.clear();
                _hasError = true;
                _errorMessage = _parseErrorMessage(state.errorMessage);
              });
              
              // Clear OTP field visually
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  // Trigger OTP field reset if possible
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
          final showOtp = state.session != null;
          final phoneNumber = state.phoneNumber ?? '';


          if (_isLoadingSavedPhone) {
            return _buildLoadingState();
          }

          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
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
                        child: _buildPhoneSection(context, state, showOtp, phoneNumber),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _primaryColor,
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
      ),
    );
  }

  Widget _buildHeader(bool showOtp, String phoneNumber) {
    return Column(
      children: [
        // Circular gradient dots
        _buildCircularGradientDots(),
        const SizedBox(height: 32),
        if (showOtp)
          Text(
            'Verify Your Number',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          showOtp
              ? 'We sent a 6-digit code to\n$phoneNumber'
              : 'Enter your phone number to continue',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            fontFamily: 'SF Pro Display',
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSection(BuildContext context, AuthState state, bool isReadOnly, String phoneNumber) {
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
            _buildHeader(isReadOnly, phoneNumber),
            const SizedBox(height: 32),
            if (!isReadOnly) ...[
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF871C1C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: TextFormField(
                controller: _phoneController,
                enabled: !isReadOnly,
                readOnly: isReadOnly,
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
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: state.status == ViewStatus.loading
                    ? null
                    : () {
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
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: _primaryColor.withOpacity(0.5),
                ),
                child: state.status == ViewStatus.loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            ] else ...[
            // OTP Section - Single text field like Apple's design
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
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  ),
                ),
              ),
            ],
            if (_hasError && _errorMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.redAccent.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.1),
                      blurRadius: 12,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Colors.redAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_errorMessage!.toLowerCase().contains('expired') ||
                        _errorMessage!.toLowerCase().contains('invalid')) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.redAccent.withOpacity(0.8),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You can request a new code below',
                              style: TextStyle(
                                color: Colors.redAccent.withOpacity(0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sms_outlined,
                    size: 18,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Didn't receive code?",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_resendCountdown > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_resendCountdown',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor.withOpacity(0.2),
                            _primaryColor.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _primaryColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () => _handleResendOtp(context, phoneNumber),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: 16,
                              color: _primaryColor,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Resend',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _handleChangeNumber(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: Colors.white.withOpacity(0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Change number',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCircularGradientDots() {
    return ICloudDottedCircle(
      size: 200,
    );
  }

}
