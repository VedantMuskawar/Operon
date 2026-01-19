import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:operon_auth_flow/operon_auth_flow.dart';
import 'package:operon_driver_android/presentation/views/driver_home_page.dart';
import 'package:operon_driver_android/presentation/views/organization_selection_page.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _page(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => _page(
          key: state.pageKey,
          child: const UnifiedLoginPage(),
        ),
      ),
      GoRoute(
        path: '/otp',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/org-selection',
        name: 'org-selection',
        pageBuilder: (context, state) => _page(
          key: state.pageKey,
          child: const OrganizationSelectionPage(),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        redirect: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          if (orgState.isRestoring) return null;
          if (!orgState.hasSelection) return '/org-selection';
          return null;
        },
        pageBuilder: (context, state) => _page(
          key: state.pageKey,
          child: const DriverHomePage(),
        ),
      ),
    ],
  );
}

Page<dynamic> _page({
  required LocalKey key,
  required Widget child,
}) {
  return MaterialPage<dynamic>(
    key: key,
    child: child,
  );
}

