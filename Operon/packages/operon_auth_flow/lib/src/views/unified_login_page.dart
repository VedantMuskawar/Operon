import 'package:core_bloc/core_bloc.dart';
import 'package:core_ui/core_ui.dart'
    show
        AuthColors,
        DashSnackbar,
        DotGridPattern,
        UnifiedLoginContent,
        parseAuthErrorMessage;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/src/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:operon_auth_flow/src/blocs/auth/auth_bloc.dart';
import 'package:operon_auth_flow/src/blocs/org_context/org_context_cubit.dart';
import 'package:operon_auth_flow/src/services/org_context_persistence_service.dart';
import 'package:operon_auth_flow/src/services/phone_persistence_service.dart';

class UnifiedLoginPage extends StatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  State<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends State<UnifiedLoginPage> {
  bool _isLoadingSavedPhone = true;
  String? _initialPhoneNumber;

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
        final phoneDigits =
            digits.length > 10 ? digits.substring(digits.length - 10) : digits;
        _initialPhoneNumber = phoneDigits;
      }
    }
    if (mounted) {
      setState(() => _isLoadingSavedPhone = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: DotGridPattern(),
            ),
          ),
          _buildBody(context),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) async {
          // Handle phone submission errors (show snackbar, not in OTP mode)
          if (state.status == ViewStatus.failure && state.errorMessage != null) {
            final showOtp = state.session != null;
            if (!showOtp) {
              DashSnackbar.show(
                context,
                message: parseAuthErrorMessage(state.errorMessage),
                isError: true,
              );
            }
          }

          // Handle phone number saving
          if (state.status == ViewStatus.success && state.session != null) {
            if (state.phoneNumber != null && state.phoneNumber!.isNotEmpty) {
              await PhonePersistenceService.savePhoneNumber(state.phoneNumber!);
            }
          }

          // Handle successful authentication
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
          return previous.session?.verificationId !=
                  current.session?.verificationId ||
              previous.status != current.status ||
              previous.phoneNumber != current.phoneNumber ||
              previous.userProfile != current.userProfile;
        },
        builder: (context, state) {
          return UnifiedLoginContent(
            authState: state,
            initialPhoneNumber: _initialPhoneNumber,
            isLoadingSavedPhone: _isLoadingSavedPhone,
            onPhoneSubmitted: (phoneNumber) {
              context.read<AuthBloc>().add(PhoneNumberSubmitted(phoneNumber));
            },
            onOtpSubmitted: (verificationId, code) {
              context.read<AuthBloc>().add(
                    OtpSubmitted(
                      verificationId: verificationId,
                      code: code,
                    ),
                  );
            },
            onAuthReset: () {
              context.read<AuthBloc>().add(const AuthReset());
            },
            onPhoneSaved: (phoneNumber) async {
              await PhonePersistenceService.savePhoneNumber(phoneNumber);
            },
          );
        },
      ),
    );
  }
}

