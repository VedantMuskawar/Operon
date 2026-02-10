import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/repositories/raw_materials_repository.dart';
import 'package:core_datasources/core_datasources.dart';
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
import 'package:dash_mobile/presentation/blocs/raw_materials/raw_materials_cubit.dart';
import 'package:dash_mobile/presentation/blocs/roles/roles_cubit.dart';
import 'package:dash_mobile/presentation/blocs/users/users_cubit.dart';
import 'package:dash_mobile/presentation/blocs/delivery_zones/delivery_zones_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payment_accounts/payment_accounts_cubit.dart';
import 'package:dash_mobile/presentation/blocs/access_control/access_control_cubit.dart';
import 'package:dash_mobile/presentation/views/home_page.dart';
import 'package:dash_mobile/presentation/views/organization_selection_page.dart';
import 'package:dash_mobile/presentation/views/unified_login_page.dart';
import 'package:dash_mobile/presentation/views/splash_screen.dart';
import 'package:dash_mobile/presentation/views/products_page.dart';
import 'package:dash_mobile/presentation/views/raw_materials_page.dart';
import 'package:dash_mobile/presentation/views/roles_page.dart';
import 'package:dash_mobile/presentation/views/employees_page.dart';
import 'package:dash_mobile/presentation/views/employees_page/employee_detail_page.dart';
import 'package:dash_mobile/presentation/views/vendors_page.dart';
import 'package:dash_mobile/presentation/views/vendors_page/vendor_detail_page.dart';
import 'package:dash_mobile/presentation/blocs/vendors/vendors_cubit.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_mobile/presentation/views/users_page.dart';
import 'package:dash_mobile/presentation/views/zones_page.dart';
import 'package:dash_mobile/presentation/views/payment_accounts_page.dart';
import 'package:dash_mobile/presentation/views/clients_page.dart';
import 'package:dash_mobile/presentation/views/clients_page/client_detail_page.dart';
import 'package:dash_mobile/presentation/views/vehicles_page.dart';
import 'package:dash_mobile/presentation/views/access_control_page.dart';
import 'package:dash_mobile/presentation/views/delivery_memos_page.dart';
import 'package:dash_mobile/presentation/views/payments/record_payment_page.dart';
import 'package:dash_mobile/presentation/views/purchases/record_purchase_page.dart';
import 'package:dash_mobile/presentation/views/employee_wages/employee_wages_page.dart';
import 'package:dash_mobile/presentation/blocs/employee_wages/employee_wages_cubit.dart';
import 'package:dash_mobile/presentation/blocs/payments/payments_cubit.dart';
import 'package:dash_mobile/presentation/views/expenses/expense_sub_categories_page.dart';
import 'package:dash_mobile/presentation/views/expenses/record_expense_page.dart'
    show ExpenseFormType, RecordExpensePage;
import 'package:dash_mobile/presentation/views/accounts_ledger_page.dart';
import 'package:dash_mobile/presentation/blocs/expense_sub_categories/expense_sub_categories_cubit.dart';
import 'package:dash_mobile/presentation/views/financial_transactions/unified_financial_transactions_page.dart';
import 'package:dash_mobile/presentation/views/financial_transactions/salary_voucher_page.dart';
import 'package:dash_mobile/presentation/blocs/financial_transactions/unified_financial_transactions_cubit.dart';
import 'package:dash_mobile/presentation/views/dm_settings_page.dart';
import 'package:dash_mobile/presentation/blocs/dm_settings/dm_settings_cubit.dart';
import 'package:dash_mobile/data/repositories/dm_settings_repository.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/presentation/views/attendance_page.dart';
import 'package:dash_mobile/presentation/views/profile_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dash_mobile/presentation/widgets/back_button_handler.dart';

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
        pageBuilder: (context, state) {
          // Extract navigation args, handling both new format (HomeNavigationArgs) and old format (int)
          final args = state.extra is HomeNavigationArgs
              ? state.extra as HomeNavigationArgs
              : HomeNavigationArgs(
                  initialIndex: state.extra is int ? state.extra as int : 0,
                );

          return _buildTransitionPage(
            key: state.pageKey,
            child: HomePage(
              initialIndex: args.initialIndex,
              preFetchedPendingOrdersCount: args.preFetchedPendingOrdersCount,
            ),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          if (!orgState.hasSelection) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const ProfilePage(),
          );
        },
      ),
      GoRoute(
        path: '/roles',
        name: 'roles',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
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
          final role = orgState.appAccessRole;
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
        path: '/raw-materials',
        name: 'raw-materials',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.appAccessRole;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final rawMaterialsRepository = context.read<RawMaterialsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => RawMaterialsCubit(
                repository: rawMaterialsRepository,
                orgId: organization.id,
                canCreate: role.canCreate('rawMaterials'),
                canEdit: role.canEdit('rawMaterials'),
                canDelete: role.canDelete('rawMaterials'),
              )..loadRawMaterials(),
              child: const RawMaterialsPage(),
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
          final role = orgState.appAccessRole;
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
        path: '/employees/detail',
        name: 'employee-detail',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final employee = state.extra is OrganizationEmployee
              ? state.extra as OrganizationEmployee
              : null;
          if (organization == null || employee == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const EmployeesPage(),
            );
          }
          final employeesRepository = context.read<EmployeesRepository>();
          final rolesRepository = context.read<RolesRepository>();
          final role = orgState.appAccessRole;

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => EmployeesCubit(
                repository: employeesRepository,
                rolesRepository: rolesRepository,
                organizationId: organization.id,
                canCreate: role?.canCreate('employees') ?? false,
                canEdit: role?.canEdit('employees') ?? false,
                canDelete: role?.canDelete('employees') ?? false,
              )..load(),
              child: EmployeeDetailPage(employee: employee),
            ),
          );
        },
      ),
      GoRoute(
        path: '/vendors',
        name: 'vendors',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.appAccessRole;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final vendorsRepository = context.read<VendorsRepository>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => VendorsCubit(
                repository: vendorsRepository,
                organizationId: organization.id,
                canCreate: role.canCreate('vendors'),
                canEdit: role.canEdit('vendors'),
                canDelete: role.canDelete('vendors'),
              )..load(),
              child: const VendorsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/vendors/detail',
        name: 'vendor-detail',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final vendor = state.extra is Vendor ? state.extra as Vendor : null;
          if (organization == null || vendor == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const VendorsPage(),
            );
          }
          final vendorsRepository = context.read<VendorsRepository>();
          final role = orgState.appAccessRole;

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => VendorsCubit(
                repository: vendorsRepository,
                organizationId: organization.id,
                canCreate: role?.canCreate('vendors') ?? false,
                canEdit: role?.canEdit('vendors') ?? false,
                canDelete: role?.canDelete('vendors') ?? false,
              )..load(),
              child: VendorDetailPage(vendor: vendor),
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
          final role = orgState.appAccessRole;
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
          final role = orgState.appAccessRole;
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
          final role = orgState.appAccessRole;
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
          final role = orgState.appAccessRole;
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
          final client =
              state.extra is ClientRecord ? state.extra as ClientRecord : null;
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
          final role = orgState.appAccessRole;
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
          final role = orgState.appAccessRole;
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
      GoRoute(
        path: '/delivery-memos',
        name: 'delivery-memos',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const DeliveryMemosPage(),
          );
        },
      ),
      GoRoute(
        path: '/record-payment',
        name: 'record-payment',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final clientsRepository = context.read<ClientsRepository>();
          final transactionsRepository = context.read<TransactionsRepository>();
          final clientLedgerRepository = context.read<ClientLedgerRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) => ClientsCubit(
                    repository: clientsRepository,
                  )..subscribeToRecent(),
                ),
                BlocProvider(
                  create: (_) => PaymentsCubit(
                    transactionsRepository: transactionsRepository,
                    clientLedgerRepository: clientLedgerRepository,
                    organizationId: organization.id,
                  ),
                ),
              ],
              child: const RecordPaymentPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/transactions',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/record-purchase',
        name: 'record-purchase',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const RecordPurchasePage(),
          );
        },
      ),
      GoRoute(
        path: '/purchases',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/employee-wages',
        name: 'employee-wages',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final employeeWagesRepository =
              context.read<EmployeeWagesRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => EmployeeWagesCubit(
                repository: employeeWagesRepository,
                organizationId: organization.id,
              )..watchTransactions(),
              child: const EmployeeWagesPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/attendance',
        name: 'attendance',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          final role = orgState.appAccessRole;
          if (organization == null || role == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          // Check if user can access employees page (attendance is related to employees)
          if (!role.canAccessPage('employees') && !role.isAdmin) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const HomePage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const AttendancePage(),
          );
        },
      ),
      GoRoute(
        path: '/financial-transactions',
        name: 'financial-transactions',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final transactionsRepository = context.read<TransactionsRepository>();
          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => UnifiedFinancialTransactionsCubit(
                transactionsRepository: transactionsRepository,
                organizationId: organization.id,
              ),
              child: const UnifiedFinancialTransactionsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/accounts',
        name: 'accounts-ledger',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const AccountsLedgerPage(),
          );
        },
      ),
      GoRoute(
        path: '/expenses',
        redirect: (context, state) => '/financial-transactions',
      ),
      GoRoute(
        path: '/salary-voucher',
        name: 'salary-voucher',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          if (orgState.organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          return _buildTransitionPage(
            key: state.pageKey,
            child: const SalaryVoucherPage(),
          );
        },
      ),
      GoRoute(
        path: '/expense-sub-categories',
        name: 'expense-sub-categories',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final subCategoriesRepository =
              context.read<ExpenseSubCategoriesRepository>();
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => ExpenseSubCategoriesCubit(
                repository: subCategoriesRepository,
                organizationId: organization.id,
                userId: userId,
              )..load(),
              child: const ExpenseSubCategoriesPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/dm-settings',
        name: 'dm-settings',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final dmSettingsRepository = context.read<DmSettingsRepository>();
          final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

          return _buildTransitionPage(
            key: state.pageKey,
            child: BlocProvider(
              create: (_) => DmSettingsCubit(
                repository: dmSettingsRepository,
                orgId: organization.id,
                userId: userId,
              )..loadSettings(),
              child: const DmSettingsPage(),
            ),
          );
        },
      ),
      GoRoute(
        path: '/record-expense',
        name: 'record-expense',
        pageBuilder: (context, state) {
          final orgState = context.read<OrganizationContextCubit>().state;
          final organization = orgState.organization;
          if (organization == null) {
            return _buildTransitionPage(
              key: state.pageKey,
              child: const OrganizationSelectionPage(),
            );
          }
          final transactionsDataSource = context.read<TransactionsDataSource>();
          final vendorsRepository = context.read<VendorsRepository>();
          final employeesRepository = context.read<EmployeesRepository>();
          final subCategoriesRepository =
              context.read<ExpenseSubCategoriesRepository>();
          final paymentAccountsDataSource =
              context.read<PaymentAccountsDataSource>();

          return _buildTransitionPage(
            key: state.pageKey,
            child: MultiRepositoryProvider(
              providers: [
                RepositoryProvider.value(value: transactionsDataSource),
                RepositoryProvider.value(value: vendorsRepository),
                RepositoryProvider.value(value: employeesRepository),
                RepositoryProvider.value(value: subCategoriesRepository),
                RepositoryProvider.value(value: paymentAccountsDataSource),
              ],
              child: RecordExpensePage(
                type: state.extra is ExpenseFormType
                    ? state.extra as ExpenseFormType
                    : null,
                vendorId: state.uri.queryParameters['vendorId'],
                employeeId: state.uri.queryParameters['employeeId'],
              ),
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
    child: BackButtonHandler(
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Use easeOutCubic for natural, smooth motion
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      // Combine scale and fade for iOS-like transition
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(
            begin: 0.95,
            end: 1.0,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
