import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/access_control/access_control_cubit.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/products/products_cubit.dart';
import 'package:dash_web/presentation/blocs/raw_materials/raw_materials_cubit.dart';
import 'package:dash_web/presentation/views/home_page.dart';
import 'package:dash_web/presentation/views/organization_selection_page.dart';
import 'package:dash_web/presentation/views/unified_login_page.dart';
import 'package:dash_web/presentation/views/splash_screen.dart';
import 'package:dash_web/presentation/views/access_control_page.dart';
import 'package:dash_web/presentation/views/payment_accounts_page.dart';
// Deferred imports for code splitting
import 'package:dash_web/presentation/views/products_page.dart'
    deferred as products;
import 'package:dash_web/presentation/views/raw_materials_page.dart'
    deferred as raw_materials;
import 'package:dash_web/presentation/views/roles_page.dart';
import 'package:dash_web/presentation/views/users_view.dart';
// Deferred import for employees page (large data sets)
import 'package:dash_web/presentation/views/employees_view.dart'
    deferred as employees_view;
import 'package:dash_web/presentation/views/organization_locations_page.dart';
import 'package:dash_web/presentation/views/geofence_editor_page.dart';
import 'package:dash_web/presentation/views/notifications_page.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_web/presentation/views/vendors_view.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_web/presentation/views/zones_view.dart';
import 'package:dash_web/presentation/views/create_order_page.dart';
import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
// Deferred import for clients page (1500+ lines, complex filtering)
import 'package:dash_web/presentation/views/clients_view.dart'
    deferred as clients_view;
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/views/client_detail_page.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
// Deferred import for delivery memos (large lists, maps)
import 'package:dash_web/presentation/views/delivery_memos_view.dart'
    deferred as delivery_memos_view;
import 'package:dash_web/presentation/views/record_payment_page.dart';
// Deferred import for fuel ledger (analytics, charts)
import 'package:dash_web/presentation/views/fuel_ledger_page.dart'
    deferred as fuel_ledger;
// Deferred imports for wage/salary pages (large data processing)
import 'package:dash_web/presentation/views/employee_wages_page.dart'
    deferred as employee_wages_view;
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/views/monthly_salary_bonus_page.dart'
    deferred as salary_bonus_view;
import 'package:dash_web/presentation/views/attendance_page.dart'
    deferred as attendance_view;
import 'package:dash_web/presentation/views/unified_financial_transactions_view.dart'
    deferred as financial_transactions;
import 'package:dash_web/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart'
    deferred as financial_transactions_cubit;
import 'package:dash_web/presentation/views/cash_ledger_view.dart'
    deferred as cash_ledger;
import 'package:dash_web/presentation/blocs/cash_ledger/cash_ledger_cubit.dart'
    deferred as cash_ledger_cubit;
import 'package:dash_web/presentation/views/wage_settings_page.dart';
import 'package:dash_web/presentation/views/production_batches_page.dart'
    deferred as production_batches;
import 'package:dash_web/presentation/views/production_wages_page.dart'
    deferred as production_wages;
import 'package:dash_web/presentation/views/trip_wages_page.dart'
    deferred as trip_wages;
import 'package:dash_web/presentation/views/salary_voucher_page.dart';
import 'package:dash_web/presentation/views/accounts_ledger_page.dart';
import 'package:dash_web/presentation/views/print_dm_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/splash',
    // Use path-based routing (not hash-based) to avoid #/home issues with print route
    routerNeglect: false,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'phone-input',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const UnifiedLoginPage(),
        ),
      ),
      GoRoute(
        path: '/otp',
        name: 'otp-verification',
        redirect: (context, state) => '/login',
      ),
      GoRoute(
        path: '/org-selection',
        name: 'org-selection',
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const OrganizationSelectionPage(),
        ),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        redirect: (context, state) {
          try {
            // Check initialization state first
            try {
              final initState = context.read<AppInitializationCubit>().state;

              // If initialization hasn't started or is in progress, go to splash
              if (initState.status == AppInitializationStatus.initial ||
                  initState.status == AppInitializationStatus.checkingAuth ||
                  initState.status ==
                      AppInitializationStatus.loadingOrganizations ||
                  initState.status ==
                      AppInitializationStatus.restoringContext) {
                return '/splash';
              }

              // If context was restored, check org context
              if (initState.status == AppInitializationStatus.contextRestored) {
                final orgState = context.read<OrganizationContextCubit>().state;
                if (orgState.hasSelection) {
                  return null; // Allow navigation - context was successfully restored
                }
                return '/splash';
              }
            } catch (_) {
              // AppInitializationCubit might not be available, continue
            }

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
          } catch (_) {
            // If cubit is not available, redirect to org-selection
            return '/org-selection';
          }
        },
        pageBuilder: (context, state) {
          final initialIndex = state.uri.queryParameters['section'];
          final index =
              initialIndex != null ? int.tryParse(initialIndex) : null;
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: HomePage(initialIndex: index ?? 0),
          );
        },
      ),
      GoRoute(
        path: '/',
        name: 'dashboard',
        redirect: (context, state) {
          // On hot restart, always go to splash first to ensure initialization
          try {
            final initState = context.read<AppInitializationCubit>().state;
            final orgState = context.read<OrganizationContextCubit>().state;

            // If context is already restored, go directly to home
            if (initState.status == AppInitializationStatus.contextRestored &&
                orgState.hasSelection) {
              return '/home';
            }

            // Otherwise, go to splash for initialization
            return '/splash';
          } catch (_) {
            return '/splash';
          }
        },
      ),
      GoRoute(
        path: '/users',
        name: 'users',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          // If user is not authenticated, redirect to login
          if (authState.userProfile == null) {
            return '/login';
          }
          // If no organization context, redirect to org-selection
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null; // Allow navigation
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const WebUsersView(),
        ),
      ),
      GoRoute(
        path: '/employees',
        name: 'employees',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const _EmployeesPageWrapper(),
        ),
      ),
      GoRoute(
        path: '/locations-geofences',
        name: 'locations-geofences',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const OrganizationLocationsPage(),
        ),
      ),
      GoRoute(
        path: '/geofence-editor',
        name: 'geofence-editor',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final geofenceId = state.uri.queryParameters['geofenceId'];
          final locationId = state.uri.queryParameters['locationId'];
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: GeofenceEditorPage(
              geofenceId: geofenceId,
              locationId: locationId,
            ),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const NotificationsPage(),
        ),
      ),
      GoRoute(
        path: '/vendors',
        name: 'vendors',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const _VendorsPageWrapper(),
        ),
      ),
      GoRoute(
        path: '/roles',
        name: 'roles',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          // If user is not authenticated, redirect to login
          if (authState.userProfile == null) {
            return '/login';
          }
          // If no organization context, redirect to org-selection
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null; // Allow navigation
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const RolesPage(),
        ),
      ),
      GoRoute(
        path: '/products',
        name: 'products',
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: products.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                final appAccessRole = orgState.appAccessRole;
                if (organization == null || appAccessRole == null) {
                  return const OrganizationSelectionPage();
                }
                final productsRepository = context.read<ProductsRepository>();

                return BlocProvider(
                  create: (_) => ProductsCubit(
                    repository: productsRepository,
                    orgId: organization.id,
                    canCreate: appAccessRole.canCreate('products'),
                    canEdit: appAccessRole.canEdit('products'),
                    canDelete: appAccessRole.canDelete('products'),
                  )..load(),
                  child: products.ProductsPage(),
                );
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/raw-materials',
        name: 'raw-materials',
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: raw_materials.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                final appAccessRole = orgState.appAccessRole;
                if (organization == null || appAccessRole == null) {
                  return const OrganizationSelectionPage();
                }
                final rawMaterialsRepository =
                    context.read<RawMaterialsRepository>();

                return BlocProvider(
                  create: (_) => RawMaterialsCubit(
                    repository: rawMaterialsRepository,
                    orgId: organization.id,
                    canCreate: appAccessRole.canCreate('rawMaterials'),
                    canEdit: appAccessRole.canEdit('rawMaterials'),
                    canDelete: appAccessRole.canDelete('rawMaterials'),
                  )..loadRawMaterials(),
                  child: raw_materials.RawMaterialsPage(),
                );
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/payment-accounts',
        name: 'payment-accounts',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          // If user is not authenticated, redirect to login
          if (authState.userProfile == null) {
            return '/login';
          }
          // If no organization context, redirect to org-selection
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null; // Allow navigation
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const PaymentAccountsPage(),
        ),
      ),
      GoRoute(
        path: '/access-control',
        name: 'access-control',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          // If user is not authenticated, redirect to login
          if (authState.userProfile == null) {
            return '/login';
          }
          // If no organization context, redirect to org-selection
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null; // Allow navigation
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final orgId = orgState.organization?.id;
          if (orgId == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          final appAccessRolesRepository =
              context.read<AppAccessRolesRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => AccessControlCubit(
                appAccessRolesRepository: appAccessRolesRepository,
                orgId: orgId,
              ),
              child: const AccessControlPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/zones',
        name: 'zones',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final appAccessRole = orgState.appAccessRole;
          if (organization == null || appAccessRole == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          final zonesCityPerm = ZoneCrudPermission(
            canCreate: appAccessRole.canCreate('zonesCity'),
            canEdit: appAccessRole.canEdit('zonesCity'),
            canDelete: appAccessRole.canDelete('zonesCity'),
          );
          final zonesRegionPerm = ZoneCrudPermission(
            canCreate: appAccessRole.canCreate('zonesRegion'),
            canEdit: appAccessRole.canEdit('zonesRegion'),
            canDelete: appAccessRole.canDelete('zonesRegion'),
          );
          final zonesPricePerm = ZoneCrudPermission(
            canCreate: appAccessRole.canCreate('zonesPrice'),
            canEdit: appAccessRole.canEdit('zonesPrice'),
            canDelete: appAccessRole.canDelete('zonesPrice'),
          );
          final canAccessZones = zonesCityPerm.canManage ||
              zonesRegionPerm.canManage ||
              zonesPricePerm.canManage;
          if (!canAccessZones) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const HomePage(),
            );
          }
          final deliveryZonesRepository =
              context.read<DeliveryZonesRepository>();
          final productsRepository = context.read<ProductsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => DeliveryZonesCubit(
                repository: deliveryZonesRepository,
                productsRepository: productsRepository,
                orgId: organization.id,
              )..loadZones(),
              child: _ZonesPageWrapper(
                cityPermission: zonesCityPerm,
                regionPermission: zonesRegionPerm,
                pricePermission: zonesPricePerm,
                isAdmin: appAccessRole.isAdmin,
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/clients',
        name: 'clients',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const _ClientsPageWrapper(),
        ),
      ),
      GoRoute(
        path: '/clients/detail',
        name: 'client-detail',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          final client = state.extra;
          if (client == null) {
            return '/clients';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final client = state.extra;
          if (client == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const _ClientsPageWrapper(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: ClientDetailPage(client: client as Client),
          );
        },
      ),
      GoRoute(
        path: '/create-order',
        name: 'create-order',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final client = state.extra as Client?;
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: CreateOrderPage(client: client),
          );
        },
      ),
      GoRoute(
        path: '/delivery-memos',
        name: 'delivery-memos',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildDeferredPage(
            key: state.pageKey,
            routePath: state.uri.path,
            loadLibrary: delivery_memos_view.loadLibrary,
            builder: () => delivery_memos_view.DeliveryMemosView(),
          );
        },
      ),
      GoRoute(
        path: '/transactions',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/purchases',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/fuel-ledger',
        name: 'fuel-ledger',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildDeferredPage(
            key: state.pageKey,
            routePath: state.uri.path,
            loadLibrary: fuel_ledger.loadLibrary,
            builder: () => fuel_ledger.FuelLedgerPage(),
          );
        },
      ),
      GoRoute(
        path: '/monthly-salary-bonus',
        name: 'monthly-salary-bonus',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          if (orgState.appAccessRole?.isAdmin != true) {
            return '/home';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildDeferredPage(
            key: state.pageKey,
            routePath: state.uri.path,
            loadLibrary: salary_bonus_view.loadLibrary,
            builder: () => salary_bonus_view.MonthlySalaryBonusPage(),
          );
        },
      ),
      GoRoute(
        path: '/employee-wages',
        name: 'employee-wages',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (context) => EmployeeWagesCubit(
                repository: context.read<EmployeeWagesRepository>(),
                organizationId: organization.id,
              ),
              // ⚡ Deferred loading for employee wages page
              child: FutureBuilder<void>(
                future: employee_wages_view.loadLibrary(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.0),
                            SizedBox(height: 16),
                            Text('Loading...'),
                          ],
                        ),
                      ),
                    );
                  }
                  return employee_wages_view.EmployeeWagesPage();
                },
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: '/attendance',
        name: 'attendance',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final appAccessRole = orgState.appAccessRole;
          if (organization == null || appAccessRole == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          // Check if user can access employees page (attendance is related to employees)
          if (!appAccessRole.canAccessPage('employees') &&
              !appAccessRole.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const HomePage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            // ⚡ Deferred loading for attendance page
            child: FutureBuilder<void>(
              future: attendance_view.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.0),
                          SizedBox(height: 16),
                          Text('Loading...'),
                        ],
                      ),
                    ),
                  );
                }
                return attendance_view.AttendancePage();
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/record-payment',
        name: 'record-payment',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          final clientsRepository = context.read<ClientsRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => ClientsCubit(
                repository: clientsRepository,
                orgId: organization.id,
                analyticsRepository: context.read<AnalyticsRepository>(),
              ),
              child: const RecordPaymentPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/financial-transactions',
        name: 'financial-transactions',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: Future.wait([
                financial_transactions.loadLibrary(),
                financial_transactions_cubit.loadLibrary(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                if (organization == null) {
                  return const OrganizationSelectionPage();
                }
                final transactionsRepository =
                    context.read<TransactionsRepository>();
                final vendorsRepository = context.read<VendorsRepository>();
                return BlocProvider(
                  create: (_) => financial_transactions_cubit
                      .UnifiedFinancialTransactionsCubit(
                    transactionsRepository: transactionsRepository,
                    vendorsRepository: vendorsRepository,
                    organizationId: organization.id,
                  ),
                  child:
                      financial_transactions.UnifiedFinancialTransactionsView(),
                );
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/cash-ledger',
        name: 'cash-ledger',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: Future.wait([
                cash_ledger.loadLibrary(),
                cash_ledger_cubit.loadLibrary(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                if (organization == null) {
                  return const OrganizationSelectionPage();
                }
                final transactionsRepository =
                    context.read<TransactionsRepository>();
                final vendorsRepository = context.read<VendorsRepository>();
                return BlocProvider(
                  create: (_) => cash_ledger_cubit.CashLedgerCubit(
                    transactionsRepository: transactionsRepository,
                    vendorsRepository: vendorsRepository,
                    organizationId: organization.id,
                  ),
                  child: cash_ledger.CashLedgerView(),
                );
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/accounts',
        name: 'accounts-ledger',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const AccountsLedgerPage(),
        ),
      ),
      GoRoute(
        path: '/expenses',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/salary-voucher',
        name: 'salary-voucher',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) return '/login';
          if (!orgState.hasSelection) return '/org-selection';
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: const SalaryVoucherPage(),
          );
        },
      ),
      GoRoute(
        path: '/wage-settings',
        name: 'wage-settings',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              routePath: state.uri.path,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: const WageSettingsPage(),
          );
        },
      ),
      GoRoute(
        path: '/production-batches',
        name: 'production-batches',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: production_batches.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                if (organization == null) {
                  return const OrganizationSelectionPage();
                }
                return production_batches.ProductionBatchesPage();
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/production-wages',
        name: 'production-wages',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: production_wages.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                if (organization == null) {
                  return const OrganizationSelectionPage();
                }
                return production_wages.ProductionWagesPage();
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/trip-wages',
        name: 'trip-wages',
        redirect: (context, state) {
          final authState = context.read<AuthBloc>().state;
          final orgState = context.read<OrganizationContextCubit>().state;
          if (authState.userProfile == null) {
            return '/login';
          }
          if (!orgState.hasSelection) {
            return '/org-selection';
          }
          return null;
        },
        pageBuilder: (context, state) {
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: FutureBuilder<void>(
              future: trip_wages.loadLibrary(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final orgState = context.read<OrganizationContextCubit>().state;
                final organization = orgState.organization;
                if (organization == null) {
                  return const OrganizationSelectionPage();
                }
                return trip_wages.TripWagesPage();
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/print-dm/:dmNumber',
        name: 'print-dm',
        // No authentication redirect - public route for printing
        pageBuilder: (context, state) => _buildTransitionPage(
          key: state.pageKey,
          routePath: state.uri.path,
          child: const PrintDMPage(),
        ),
      ),
    ],
  );
}

class _EmployeesPageWrapper extends StatelessWidget {
  const _EmployeesPageWrapper();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final org = orgState.organization;
    if (org == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<EmployeesCubit>(
          create: (_) => EmployeesCubit(
            repository: context.read<EmployeesRepository>(),
            jobRolesRepository: context.read<JobRolesRepository>(),
            orgId: org.id,
          )..loadEmployees(),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Employees',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        // ⚡ Deferred loading for employees page
        child: FutureBuilder<void>(
          future: employees_view.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.0),
                      SizedBox(height: 16),
                      Text('Loading...'),
                    ],
                  ),
                ),
              );
            }
            return employees_view.EmployeesPageContent();
          },
        ),
      ),
    );
  }
}

class _VendorsPageWrapper extends StatelessWidget {
  const _VendorsPageWrapper();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final org = orgState.organization;
    if (org == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<VendorsCubit>(
          create: (_) => VendorsCubit(
            repository: context.read<VendorsRepository>(),
            organizationId: org.id,
          )..loadVendors(),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Vendors',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const VendorsPageContent(),
      ),
    );
  }
}

class _ZonesPageWrapper extends StatelessWidget {
  const _ZonesPageWrapper({
    required this.cityPermission,
    required this.regionPermission,
    required this.pricePermission,
    required this.isAdmin,
  });

  final ZoneCrudPermission cityPermission;
  final ZoneCrudPermission regionPermission;
  final ZoneCrudPermission pricePermission;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return SectionWorkspaceLayout(
      panelTitle: 'Delivery Zones',
      currentIndex: -1,
      onNavTap: (index) => context.go('/home?section=$index'),
      child: ZonesPageContent(
        cityPermission: cityPermission,
        regionPermission: regionPermission,
        pricePermission: pricePermission,
        isAdmin: isAdmin,
      ),
    );
  }
}

class _ClientsPageWrapper extends StatelessWidget {
  const _ClientsPageWrapper();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final org = orgState.organization;
    if (org == null) {
      return const Scaffold(
        body: Center(child: Text('No organization selected')),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider<ClientsCubit>(
          create: (_) => ClientsCubit(
            repository: context.read<ClientsRepository>(),
            orgId: org.id,
            analyticsRepository: context.read<AnalyticsRepository>(),
          ),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Clients',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        // ⚡ Deferred loading for clients page (1500+ lines)
        child: FutureBuilder<void>(
          future: clients_view.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.0),
                      SizedBox(height: 16),
                      Text('Loading...'),
                    ],
                  ),
                ),
              );
            }
            return clients_view.ClientsPageContent();
          },
        ),
      ),
    );
  }
}

CustomTransitionPage<dynamic> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
  String? routePath,
}) {
  // Determine transition type based on route
  final isWorkspaceRoute = routePath != null &&
      (routePath.startsWith('/home') ||
          routePath.startsWith('/roles') ||
          routePath.startsWith('/users') ||
          routePath.startsWith('/employees') ||
          routePath.startsWith('/vendors') ||
          routePath.startsWith('/products') ||
          routePath.startsWith('/raw-materials') ||
          routePath.startsWith('/zones') ||
          (routePath.startsWith('/clients') &&
              !routePath.startsWith('/clients/detail')) ||
          routePath.startsWith('/access-control') ||
          routePath.startsWith('/fuel-ledger') ||
          routePath.startsWith('/employee-wages') ||
          routePath.startsWith('/monthly-salary-bonus'));

  final isAuthRoute = routePath != null &&
      (routePath.startsWith('/login') ||
          routePath.startsWith('/otp') ||
          routePath.startsWith('/splash'));

  return CustomTransitionPage<dynamic>(
    key: key,
    child: child,
    transitionDuration: isWorkspaceRoute
        ? const Duration(milliseconds: 450)
        : isAuthRoute
            ? const Duration(milliseconds: 400)
            : const Duration(milliseconds: 350),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (isWorkspaceRoute) {
        // Enhanced workspace transitions with smooth fade, scale, and slide
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
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
                curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
              ),
            ),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.98,
                end: 1.0,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
                ),
              ),
              child: child,
            ),
          ),
        );
      } else if (isAuthRoute) {
        // Enhanced auth flow transitions
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
      } else {
        // Enhanced default transitions
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
      }
    },
  );
}

/// ⚡ Helper for deferred page loading with loading indicator
CustomTransitionPage<dynamic> _buildDeferredPage({
  required LocalKey key,
  required Future<void> Function() loadLibrary,
  required Widget Function() builder,
  String? routePath,
}) {
  return _buildTransitionPage(
    key: key,
    routePath: routePath,
    child: FutureBuilder<void>(
      future: loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Show loading indicator while code chunk downloads
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.0),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading page: ${snapshot.error}'),
          );
        }
        return builder();
      },
    ),
  );
}
