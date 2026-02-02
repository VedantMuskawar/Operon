import 'package:dash_superadmin/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_superadmin/presentation/views/dashboard_redirect_logic.dart';
import 'package:dash_superadmin/presentation/views/unified_login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          if (authState.userProfile != null) {
            return '/dashboard';
          }
          return '/login';
        },
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const UnifiedLoginPage(),
        ),
      ),
      GoRoute(
        path: '/otp',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const DashboardRedirectPage(),
        ),
      ),
    ],
  );
}

CustomTransitionPage<dynamic> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
  String? routePath,
}) {
  final isAuthRoute = routePath != null &&
      (routePath == '/login' || routePath.startsWith('/login'));

  return CustomTransitionPage<dynamic>(
    key: key,
    child: child,
    transitionDuration: isAuthRoute
        ? const Duration(milliseconds: 400)
        : const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (isAuthRoute) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
          reverseCurve: Curves.easeInOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.04),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.9, curve: Curves.easeOutCubic),
              ),
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.99,
                end: 1.0,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                ),
              ),
              child: child,
            ),
          ),
        );
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.02),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: child,
        ),
      );
    },
  );
}
