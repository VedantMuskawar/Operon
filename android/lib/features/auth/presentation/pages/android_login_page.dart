import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/app_theme.dart';
import '../../../../core/config/android_config.dart';
import '../../../../core/phone_input_field.dart';
import '../../../../core/otp_input_field.dart';
import '../../android_auth_bloc.dart';

class AndroidLoginPage extends StatefulWidget {
  const AndroidLoginPage({super.key});

  @override
  State<AndroidLoginPage> createState() => _AndroidLoginPageState();
}

class _AndroidLoginPageState extends State<AndroidLoginPage> with TickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  bool _isOTPSent = false;
  String _currentPhoneNumber = '';

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: AndroidConfig.mediumAnimationDuration,
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _sendOTP() {
    if (_formKey.currentState!.validate()) {
      context.read<AndroidAuthBloc>().add(
        AndroidAuthSendOTPRequested(phoneNumber: _phoneController.text.trim()),
      );
    }
  }

  void _verifyOTP() {
    if (_formKey.currentState!.validate()) {
      context.read<AndroidAuthBloc>().add(
        AndroidAuthLoginRequested(
          phoneNumber: _currentPhoneNumber,
          otp: _otpController.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AndroidAuthBloc, AndroidAuthState>(
        listener: (context, state) {
          if (state is AndroidAuthOTPSent) {
            setState(() {
              _isOTPSent = true;
              _currentPhoneNumber = state.phoneNumber;
            });
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('OTP sent successfully!'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
            );
          } else if (state is AndroidAuthFailure) {
            HapticFeedback.heavyImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AndroidConfig.cardRadius),
                ),
              ),
            );
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF141416), // PaveBoard background
                Color(0xFF0A0A0B),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AndroidConfig.defaultPadding),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildLoginCard(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1F2937), // gray-800/40
              Color(0xFF374151), // gray-700/30
              Color(0xFF1F2937), // gray-800/40
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0x66FFFFFF), // rgba(255,255,255,0.4)
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 32,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                if (!_isOTPSent) ...[
                  _buildPhoneInput(),
                  const SizedBox(height: 24),
                  _buildSendOTPButton(),
                ] else ...[
                  _buildOTPInput(),
                  const SizedBox(height: 24),
                  _buildVerifyOTPButton(),
                  const SizedBox(height: 16),
                  _buildResendOTPButton(),
                ],
                const SizedBox(height: 24),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)], // blue-500 to purple-600
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.business,
            size: 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF60A5FA), Color(0xFFA78BFA)], // blue-400 to purple-400
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            _isOTPSent ? 'Verify OTP' : 'Welcome to OPERON',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isOTPSent ? 'Enter the verification code' : 'Sign in with your phone number',
          style: const TextStyle(
            color: Color(0xFF9CA3AF), // gray-400
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📱 Phone Number',
          style: TextStyle(
            color: Color(0xFFD1D5DB), // gray-300
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withValues(alpha: 0.5), // gray-700/50
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4B5563).withValues(alpha: 0.5), // gray-600/50
            ),
          ),
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              color: Color(0xFFF9FAFB), // gray-50
              fontSize: 16,
            ),
            decoration: const InputDecoration(
              hintText: '98765 43210',
              hintStyle: TextStyle(
                color: Color(0xFF6B7280), // gray-500
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your phone number';
              }
              if (value.length != 10) {
                return 'Please enter exactly 10 digits';
              }
              if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                return 'Please enter a valid Indian mobile number';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          children: [
            Icon(
              Icons.lightbulb_outline,
              color: Color(0xFF6B7280), // gray-500
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              "We'll send you a verification code",
              style: TextStyle(
                color: Color(0xFF6B7280), // gray-500
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOTPInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔢 Verification Code',
          style: TextStyle(
            color: Color(0xFFD1D5DB), // gray-300
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withValues(alpha: 0.5), // gray-700/50
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4B5563).withValues(alpha: 0.5), // gray-600/50
            ),
          ),
          child: TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF9FAFB), // gray-50
              fontSize: 24,
              fontWeight: FontWeight.w500,
              letterSpacing: 8,
            ),
            decoration: const InputDecoration(
              hintText: '123456',
              hintStyle: TextStyle(
                color: Color(0xFF6B7280), // gray-500
                letterSpacing: 8,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter OTP';
              }
              if (value.length != 6) {
                return 'Please enter 6-digit OTP';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.phone_android,
              color: Color(0xFF6B7280), // gray-500
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              'Enter the 6-digit code sent to $_currentPhoneNumber',
              style: const TextStyle(
                color: Color(0xFF6B7280), // gray-500
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSendOTPButton() {
    return BlocBuilder<AndroidAuthBloc, AndroidAuthState>(
      builder: (context, state) {
        final isLoading = state is AndroidAuthLoading;
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)], // blue-500 to purple-600
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : _sendOTP,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sending...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Send OTP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerifyOTPButton() {
    return BlocBuilder<AndroidAuthBloc, AndroidAuthState>(
      builder: (context, state) {
        final isLoading = state is AndroidAuthLoading;
        return Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)], // green-500 to emerald-600
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : _verifyOTP,
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Verifying...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Verify OTP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResendOTPButton() {
    return BlocBuilder<AndroidAuthBloc, AndroidAuthState>(
      builder: (context, state) {
        final isLoading = state is AndroidAuthLoading;
        return Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF374151).withValues(alpha: 0.5), // gray-700/50
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF4B5563).withValues(alpha: 0.5), // gray-600/50
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isLoading ? null : () {
                setState(() {
                  _isOTPSent = false;
                  _otpController.clear();
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFD1D5DB), // gray-300
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back',
                      style: TextStyle(
                        color: isLoading ? const Color(0xFF6B7280) : const Color(0xFFD1D5DB), // gray-500 : gray-300
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return const Center(
      child: Text(
        'Secure authentication powered by Firebase',
        style: TextStyle(
          color: Color(0xFF6B7280), // gray-500
          fontSize: 12,
        ),
      ),
    );
  }
}



