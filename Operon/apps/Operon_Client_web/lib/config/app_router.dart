import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_web/presentation/blocs/access_control/access_control_cubit.dart';
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
import 'package:dash_web/presentation/views/products_page.dart';
import 'package:dash_web/presentation/views/raw_materials_page.dart';
import 'package:dash_web/presentation/views/roles_page.dart';
import 'package:dash_web/presentation/views/users_view.dart';
import 'package:dash_web/presentation/views/employees_view.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/presentation/blocs/employees/employees_cubit.dart';
import 'package:dash_web/presentation/views/vendors_view.dart';
import 'package:dash_web/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:dash_web/presentation/views/zones_view.dart';
import 'package:dash_web/presentation/views/create_order_page.dart';
import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:dash_web/presentation/views/clients_view.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/presentation/blocs/clients/clients_cubit.dart';
import 'package:dash_web/presentation/views/client_detail_page.dart';
import 'package:dash_web/domain/entities/client.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/views/delivery_memos_view.dart';
import 'package:dash_web/presentation/views/transactions_page.dart';
import 'package:dash_web/presentation/views/purchases_page.dart';
import 'package:dash_web/presentation/views/record_payment_page.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/presentation/views/fuel_ledger_page.dart';
import 'package:dash_web/presentation/views/employee_wages_page.dart';
import 'package:dash_web/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_web/presentation/views/expenses_page.dart';
import 'package:dash_web/presentation/blocs/expenses/expenses_cubit.dart';
import 'package:dash_web/presentation/views/wage_settings_page.dart';
import 'package:dash_web/presentation/views/production_batches_page.dart';
import 'package:dash_web/presentation/views/production_wages_page.dart';
import 'package:dash_web/presentation/views/trip_wages_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          } catch (e) {
            // If cubit is not available, redirect to org-selection
            return '/org-selection';
          }
        },
        pageBuilder: (context, state) {
          final initialIndex = state.uri.queryParameters['section'];
          final index = initialIndex != null ? int.tryParse(initialIndex) : null;
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
        redirect: (context, state) => '/home',
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
          final productsRepository = context.read<ProductsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => ProductsCubit(
                repository: productsRepository,
                orgId: organization.id,
                canCreate: appAccessRole.canCreate('products'),
                canEdit: appAccessRole.canEdit('products'),
                canDelete: appAccessRole.canDelete('products'),
              )..load(),
              child: const ProductsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/raw-materials',
        name: 'raw-materials',
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
          final rawMaterialsRepository = context.read<RawMaterialsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => RawMaterialsCubit(
                repository: rawMaterialsRepository,
                orgId: organization.id,
                canCreate: appAccessRole.canCreate('rawMaterials'),
                canEdit: appAccessRole.canEdit('rawMaterials'),
                canDelete: appAccessRole.canDelete('rawMaterials'),
              )..loadRawMaterials(),
              child: const RawMaterialsPage(),
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
          final appAccessRolesRepository = context.read<AppAccessRolesRepository>();
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
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: const DeliveryMemosView(),
          );
        },
      ),
      GoRoute(
        path: '/transactions',
        name: 'transactions',
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
            child: const TransactionsPage(),
          );
        },
      ),
      GoRoute(
        path: '/purchases',
        name: 'purchases',
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
            child: const PurchasesPage(),
          );
        },
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
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: const FuelLedgerPage(),
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
              )..watchTransactions(),
              child: const EmployeeWagesPage(),
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
        path: '/expenses',
        name: 'expenses',
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
          final transactionsRepository = context.read<TransactionsRepository>();
          final vendorsRepository = context.read<VendorsRepository>();
          final employeesRepository = context.read<EmployeesRepository>();
          final subCategoriesRepository = context.read<ExpenseSubCategoriesRepository>();
          final paymentAccountsDataSource = PaymentAccountsDataSource();
          final userId = context.read<AuthBloc>().state.userProfile?.id ?? '';
          
          return _buildTransitionPage(
            key: state.pageKey,
            routePath: state.uri.path,
            child: BlocProvider(
              create: (_) => ExpensesCubit(
                transactionsRepository: transactionsRepository,
                vendorsRepository: vendorsRepository,
                employeesRepository: employeesRepository,
                subCategoriesRepository: subCategoriesRepository,
                paymentAccountsDataSource: paymentAccountsDataSource,
                organizationId: organization.id,
                userId: userId,
              )..load(),
              child: const ExpensesPage(),
            ),
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
            child: const ProductionBatchesPage(),
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
            child: const ProductionWagesPage(),
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
            child: const TripWagesPage(),
          );
        },
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
        child: const EmployeesPageContent(),
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
        child: const ClientsPageContent(),
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
          (routePath.startsWith('/clients') && !routePath.startsWith('/clients/detail')) ||
          routePath.startsWith('/access-control') ||
          routePath.startsWith('/fuel-ledger') ||
          routePath.startsWith('/employee-wages'));
  
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
