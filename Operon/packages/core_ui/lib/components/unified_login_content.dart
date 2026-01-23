import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared error message parser for authentication errors
String parseAuthErrorMessage(String? rawError) {
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

/// Shared unified login content widget
/// Handles both phone input and OTP verification states
class UnifiedLoginContent extends StatefulWidget {
  const UnifiedLoginContent({
    super.key,
    required this.authState,
    required this.onPhoneSubmitted,
    required this.onOtpSubmitted,
    required this.onAuthReset,
    this.onPhoneSaved,
    this.initialPhoneNumber,
    this.isLoadingSavedPhone = false,
  });

  final dynamic authState; // AuthState from app-specific AuthBloc
  final void Function(String phoneNumber) onPhoneSubmitted;
  final void Function(String verificationId, String code) onOtpSubmitted;
  final VoidCallback onAuthReset;
  final Future<void> Function(String phoneNumber)? onPhoneSaved;
  final String? initialPhoneNumber;
  final bool isLoadingSavedPhone;

  @override
  State<UnifiedLoginContent> createState() => _UnifiedLoginContentState();
}

class _UnifiedLoginContentState extends State<UnifiedLoginContent> {
  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;
  final _resendCountdownNotifier = ValueNotifier<int>(0);
  bool _hasError = false;
  String? _errorMessage;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialPhoneNumber);
    _otpController = TextEditingController();
  }

  @override
  void didUpdateWidget(UnifiedLoginContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPhoneNumber != oldWidget.initialPhoneNumber &&
        widget.initialPhoneNumber != null) {
      _phoneController.text = widget.initialPhoneNumber!;
    }
    
    // Start countdown when OTP is sent (session becomes available)
    final hadSession = _hasSession(oldWidget.authState);
    final hasSession = _hasSession(widget.authState);
    if (!hadSession && hasSession && _resendCountdownNotifier.value == 0 && mounted) {
      _startResendCountdown();
      if (mounted) {
        setState(() {
          _hasError = false;
          _errorMessage = null;
        });
      }
    }
  }
  
  bool _hasSession(dynamic authState) {
    try {
      final session = authState.session;
      return session != null && session.verificationId != null;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _phoneController.dispose();
    _otpController.dispose();
    _resendCountdownNotifier.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    if (!mounted) return;
    _resendCountdownNotifier.value = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendCountdownNotifier.value <= 0) {
        timer.cancel();
        _resendTimer = null;
        return;
      }
      if (mounted) {
        _resendCountdownNotifier.value--;
      }
    });
  }

  void _handleResendOtp(String phoneNumber) {
    widget.onPhoneSubmitted(phoneNumber);
    _startResendCountdown();
    if (mounted) {
      setState(() {
        _otpController.clear();
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  void _handleChangeNumber() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendCountdownNotifier.value = 0;
    widget.onAuthReset();
    if (mounted) {
      setState(() {
        _otpController.clear();
        _hasError = false;
      });
    }
  }

  // Helper to check if OTP should be shown
  // Assumes authState has a 'session' property with 'verificationId'
  bool get _showOtp {
    try {
      final session = widget.authState.session;
      return session != null && session.verificationId != null;
    } catch (_) {
      return false;
    }
  }

  // Helper to get phone number from auth state
  String get _phoneNumber {
    try {
      return widget.authState.phoneNumber ?? '';
    } catch (_) {
      return '';
    }
  }

  // Helper to get loading status
  // Assumes authState has a 'status' property that can be compared to a loading state
  bool get _isLoading {
    try {
      final status = widget.authState.status;
      // Check for common loading state names
      return status.toString().contains('loading') || 
             status.toString().toLowerCase() == 'loading';
    } catch (_) {
      return false;
    }
  }

  // Helper to get error message
  // Assumes authState has 'status' and 'errorMessage' properties
  String? get _stateErrorMessage {
    try {
      final status = widget.authState.status;
      if (status.toString().contains('failure') || 
          status.toString().toLowerCase() == 'failure') {
        return widget.authState.errorMessage;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    // Responsive padding based on screen size
    final horizontalPadding = screenWidth < 400 ? 16.0 : 24.0;
    final verticalPadding = screenHeight < 600 ? 24.0 : 40.0;

    if (widget.isLoadingSavedPhone) {
      return _buildLoadingState();
    }

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sign In header
                const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AuthColors.textMain,
                    fontFamily: 'SF Pro Display',
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 40),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth < 600 
                        ? double.infinity 
                        : (kIsWeb ? 650 : 450), // Wider for web app
                    minWidth: 280,
                  ),
                  child: _buildLoginCard(context, screenWidth),
                ),
              ],
            ),
          ),
        ),
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
                color: AuthColors.primary,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading...',
              style: TextStyle(
                color: AuthColors.textSub,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context, double screenWidth) {
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile 
        ? (screenWidth < 400 ? 24.0 : 32.0)
        : (kIsWeb ? 56.0 : 44.0); // More padding for web
    final verticalPadding = isMobile ? 32.0 : 40.0;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: isMobile ? double.infinity : (kIsWeb ? 650 : null), // Explicit width for web
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AuthColors.secondaryWithOpacity(0.3),
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
            _buildHeader(_showOtp, _phoneNumber),
            const SizedBox(height: 32),
            if (!_showOtp)
              _buildPhoneSection(context, screenWidth)
            else
              _buildOtpSection(context, _phoneNumber, screenWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool showOtp, String phoneNumber) {
    return Column(
      children: [
        // Circular gradient dots
        const RepaintBoundary(
          child: ICloudDottedCircle(size: 200),
        ),
        const SizedBox(height: 32),
        if (showOtp)
          const Text(
            'Verify Your Number',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AuthColors.textMain,
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
            color: AuthColors.textMain,
            fontFamily: 'SF Pro Display',
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneSection(BuildContext context, double screenWidth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
              width: 1,
            ),
          ),
          child: Semantics(
            label: 'Phone number input',
            hint: 'Enter your 10-digit phone number',
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 17,
                fontWeight: FontWeight.w400,
                fontFamily: 'SF Pro Display',
              ),
              decoration: const InputDecoration(
                hintText: 'Phone Number',
                hintStyle: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 17,
                  fontFamily: 'SF Pro Display',
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading
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
                    widget.onPhoneSubmitted(formattedNumber);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AuthColors.primary,
              foregroundColor: AuthColors.textMain,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              disabledBackgroundColor: AuthColors.primaryWithOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AuthColors.textMain),
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
      ],
    );
  }

  Widget _buildOtpSection(BuildContext context, String phoneNumber, double screenWidth) {
    // Update error state from auth state
    final stateError = _stateErrorMessage;
    if (stateError != null && stateError != _errorMessage && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _otpController.clear();
            _hasError = true;
            _errorMessage = parseAuthErrorMessage(stateError);
          });
        }
      });
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // OTP Input Field
        Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasError
                  ? AuthColors.error.withOpacity(0.5)
                  : AuthColors.textMainWithOpacity(0.1),
              width: 1,
            ),
          ),
          child: Semantics(
            label: 'OTP verification code input',
            hint: 'Enter the 6-digit verification code sent to your phone',
            child: TextFormField(
              controller: _otpController,
              enabled: !_isLoading,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: 12,
                fontFamily: 'SF Pro Display',
              ),
              decoration: const InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 12,
                  fontFamily: 'SF Pro Display',
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() {
                    if (_hasError && value.isNotEmpty) {
                      _hasError = false;
                      _errorMessage = null;
                    }
                  });
                }
                // Auto-submit when 6 digits are entered
                if (value.length == 6 && !_hasError && mounted) {
                  try {
                    final verificationId = widget.authState.session?.verificationId;
                    if (verificationId != null) {
                      widget.onOtpSubmitted(verificationId, value);
                    }
                  } catch (_) {
                    // Handle error silently
                  }
                }
              },
            ),
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 24),
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AuthColors.primaryWithOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AuthColors.primary),
              ),
            ),
          ),
        ],
        if (_hasError && _errorMessage != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AuthColors.error.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AuthColors.error.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AuthColors.error.withOpacity(0.1),
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
                      color: AuthColors.error,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AuthColors.error,
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
                        color: AuthColors.error.withOpacity(0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can request a new code below',
                          style: TextStyle(
                            color: AuthColors.error.withOpacity(0.9),
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
        // Resend OTP section
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          decoration: BoxDecoration(
            color: AuthColors.textMainWithOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.sms_outlined,
                size: 18,
                color: AuthColors.textSub,
              ),
              const SizedBox(width: 8),
              const Text(
                "Didn't receive code?",
                style: TextStyle(
                  fontSize: 14,
                  color: AuthColors.textSub,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<int>(
                valueListenable: _resendCountdownNotifier,
                builder: (context, countdown, _) {
                  if (countdown > 0) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AuthColors.textMainWithOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AuthColors.textMainWithOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AuthColors.textSub,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$countdown',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AuthColors.textMain,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AuthColors.primaryWithOpacity(0.2),
                          AuthColors.primaryWithOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AuthColors.primaryWithOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: TextButton(
                      onPressed: () => _handleResendOtp(phoneNumber),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 16,
                            color: AuthColors.secondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AuthColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Change number button
        Center(
          child: TextButton(
            onPressed: _handleChangeNumber,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.arrow_back_rounded,
                  size: 16,
                  color: AuthColors.textSub,
                ),
                SizedBox(width: 8),
                Text(
                  'Change number',
                  style: TextStyle(
                    fontSize: 14,
                    color: AuthColors.textSub,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
