import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/repositories/roles_repository.dart';
import 'package:dash_mobile/data/repositories/users_repository.dart';
import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/services/qr_code_service.dart';
import 'package:dash_mobile/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_mobile/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/products/products_cubit.dart';
import 'package:dash_mobile/presentation/blocs/roles/roles_cubit.dart';
import 'package:dash_mobile/presentation/blocs/users/users_cubit.dart';
import 'package:dash_mobile/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_mobile/presentation/blocs/access_control/access_control_cubit.dart';
import 'package:dash_mobile/presentation/views/home_page.dart';
import 'package:dash_mobile/presentation/views/organization_selection_page.dart';
import 'package:dash_mobile/presentation/views/otp_verification_page.dart';
import 'package:dash_mobile/presentation/views/phone_input_page.dart';
import 'package:dash_mobile/presentation/views/splash_screen.dart';
import 'package:dash_mobile/presentation/views/products_page.dart';
import 'package:dash_mobile/presentation/views/roles_page.dart';
import 'package:dash_mobile/presentation/views/employees_page.dart';
import 'package:dash_mobile/presentation/views/users_page.dart';
import 'package:dash_mobile/presentation/views/zones_page.dart';
import 'package:dash_mobile/presentation/views/payment_accounts_page.dart';
import 'package:dash_mobile/presentation/views/clients_page.dart';
import 'package:dash_mobile/presentation/views/clients_page/client_detail_page.dart';
import 'package:dash_mobile/presentation/views/vehicles_page.dart';
import 'package:dash_mobile/presentation/views/access_control_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
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
        path: '/org-selection',
        name: 'org-selection',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: const OrganizationSelectionPage(),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        redirect: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          // If context is being restored, allow navigation (restore will complete)
          if (orgState.isRestoring) {
            return null;
          }
          // If no context exists, redirect to org-selection
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null; // Allow navigation
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          child: HomePage(
            initialIndex: state.extra is int ? state.extra as int : 0,
          ),
        ),
      ),
      GoRoute(
        path: '/roles',
        name: 'roles',
        pageBuilder: (context, state) {
          final orgState =
              context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final rolesRepository = context.read<RolesRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => RolesCubit(
                repository: rolesRepository,
                orgId: organization.id,
              )..load(),
              child: const RolesPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/products',
        name: 'products',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final productsRepository = context.read<ProductsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => ProductsCubit(
                repository: productsRepository,
                orgId: organization.id,
                canCreate: role.canCreate('products'),
                canEdit: role.canEdit('products'),
                canDelete: role.canDelete('products'),
              )..load(),
              child: const ProductsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/employees',
        name: 'employees',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final employeesRepository = context.read<EmployeesRepository>();
          final rolesRepository = context.read<RolesRepository>();
          
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => EmployeesCubit(
                repository: employeesRepository,
                rolesRepository: rolesRepository,
                organizationId: organization.id,
                canCreate: role.canCreate('employees'),
                canEdit: role.canEdit('employees'),
                canDelete: role.canDelete('employees'),
              )..load(),
              child: const EmployeesPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/users',
        name: 'users',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          if (!role.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final usersRepository = context.read<UsersRepository>();
          final rolesRepository = context.read<RolesRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => UsersCubit(
                    repository: usersRepository,
                    organizationId: organization.id,
                    organizationName: organization.name,
                  )..load(),
                ),
                BlocProvider(
                  create: (_) => RolesCubit(
                    repository: rolesRepository,
                    orgId: organization.id,
                  )..load(),
                ),
              ],
              child: const UsersPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/vehicles',
        name: 'vehicles',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          if (!role.canAccessPage('vehicles')) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final vehiclesRepository = context.read<VehiclesRepository>();
          final employeesRepository = context.read<EmployeesRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: vehiclesRepository),
                RepositoryProvider.value(value: employeesRepository),
              ],
              child: const VehiclesPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/zones',
        name: 'zones',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final zonesCityPerm = ZoneCrudPermission(
            canCreate: role.canCreate('zonesCity'),
            canEdit: role.canEdit('zonesCity'),
            canDelete: role.canDelete('zonesCity'),
          );
          final zonesRegionPerm = ZoneCrudPermission(
            canCreate: role.canCreate('zonesRegion'),
            canEdit: role.canEdit('zonesRegion'),
            canDelete: role.canDelete('zonesRegion'),
          );
          final zonesPricePerm = ZoneCrudPermission(
            canCreate: role.canCreate('zonesPrice'),
            canEdit: role.canEdit('zonesPrice'),
            canDelete: role.canDelete('zonesPrice'),
          );
          final canAccessZones = zonesCityPerm.canManage ||
              zonesRegionPerm.canManage ||
              zonesPricePerm.canManage;
          if (!canAccessZones) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final deliveryZonesRepository =
              context.read<DeliveryZonesRepository>();
          final productsRepository = context.read<ProductsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => DeliveryZonesCubit(
                repository: deliveryZonesRepository,
                productsRepository: productsRepository,
                orgId: organization.id,
              )..loadZones(),
              child: ZonesPage(
                cityPermission: zonesCityPerm,
                regionPermission: zonesRegionPerm,
                pricePermission: zonesPricePerm,
                isAdmin: role.isAdmin,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/clients',
        name: 'clients',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          // Check if user can access clients page
          if (!role.canAccessPage('clients') && !role.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final clientsRepository = context.read<ClientsRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => ClientsCubit(
                repository: clientsRepository,
              )..subscribeToRecent(),
              child: const ClientsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/clients/detail',
        name: 'client-detail',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final client = state.extra is ClientRecord ? state.extra as ClientRecord : null;
          if (organization == null || client == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const ClientsPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: ClientDetailPage(client: client),
          );
        },
      ),
      GoRoute(
        path: '/payment-accounts',
        name: 'payment-accounts',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          // Admin-only access
          if (!role.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final paymentAccountsRepository =
              context.read<PaymentAccountsRepository>();
          final qrCodeService = context.read<QrCodeService>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => PaymentAccountsCubit(
                repository: paymentAccountsRepository,
                qrCodeService: qrCodeService,
                orgId: organization.id,
              )..loadAccounts(),
              child: const PaymentAccountsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/access-control',
        name: 'access-control',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.role;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          // Admin only
          if (!role.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          final rolesRepository = context.read<RolesRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => AccessControlCubit(
                rolesRepository: rolesRepository,
                orgId: organization.id,
              ),
              child: const AccessControlPage(),
            ),
          );
        },
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
    transitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
        reverseCurve: Curves.fastOutSlowIn,
      );
      return SlideTransition(
          position: Tween<Offset>(
          begin: const Offset(1.0, 0.0), // Slide from right
            end: Offset.zero,
          ).animate(curved),
          child: child,
      );
    },
  );
}
