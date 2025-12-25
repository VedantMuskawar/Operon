import 'package:dash_superadmin/presentation/views/dashboard_redirect_logic.dart';
import 'package:dash_superadmin/presentation/views/otp_verification_page.dart';
import 'package:dash_superadmin/presentation/views/phone_input_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'phone-input',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const PhoneInputPage(),
        ),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp-verification',
        pageBuilder: (context, state) {
          final phoneNumber = state.uri.queryParameters['phone'] ?? '';
          return _buildTransitionPage(
            key: state.pageKey,
            child: OtpVerificationPage(phoneNumber: phoneNumber),
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const DashboardRedirectPage(),
        ),
      ),
    ],
  );
}

CustomTransitionPage<dynamic> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<dynamic>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
