import 'package:dash_mobile/config/app_router.dart';
import 'package:dash_mobile/config/app_theme.dart';
import 'package:dash_mobile/data/repositories/auth_repository.dart';
import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/data/datasources/user_organization_data_source.dart';
import 'package:dash_mobile/data/repositories/delivery_zones_repository.dart';
import 'package:dash_mobile/data/datasources/users_data_source.dart';
import 'package:dash_mobile/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_mobile/data/datasources/pending_orders_data_source.dart';
import 'package:dash_mobile/data/repositories/pending_orders_repository.dart';
import 'package:dash_mobile/data/repositories/analytics_repository.dart';
import 'package:dash_mobile/data/repositories/clients_repository.dart';
import 'package:dash_mobile/data/repositories/employees_repository.dart';
import 'package:dash_mobile/data/repositories/products_repository.dart';
import 'package:dash_mobile/data/repositories/user_organization_repository.dart';
import 'package:dash_mobile/data/repositories/app_access_roles_repository.dart';
import 'package:dash_mobile/data/datasources/app_access_roles_data_source.dart';
import 'package:dash_mobile/data/repositories/users_repository.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/repositories/vehicles_repository.dart';
import 'package:dash_mobile/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_mobile/data/datasources/scheduled_trips_data_source.dart';
import 'package:dash_mobile/data/repositories/dm_settings_repository.dart';
import 'package:core_datasources/core_datasources.dart' hide ScheduledTripsRepository, ScheduledTripsDataSource;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/data/services/analytics_service.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/data/services/qr_code_service.dart';
import 'package:dash_mobile/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_mobile/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_mobile/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_mobile/presentation/blocs/org_selector/org_selector_cubit.dart';
import 'package:dash_mobile/presentation/widgets/caller_overlay_bootstrap.dart';
import 'package:dash_mobile/presentation/widgets/textured_background.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DashMobileApp extends StatelessWidget {
  const DashMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepository = AuthRepository();

    final organizationRepository = UserOrganizationRepository(
      dataSource: UserOrganizationDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final rolesRepository = RolesRepository(
      dataSource: RolesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final appAccessRolesRepository = AppAccessRolesRepository(
      dataSource: AppAccessRolesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final productsRepository = ProductsRepository(
      dataSource: ProductsDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final employeesRepository = EmployeesRepository(
      dataSource: EmployeesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final vendorsRepository = VendorsRepository(
      dataSource: VendorsDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final usersRepository = UsersRepository(
      dataSource: UsersDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final deliveryZonesRepository = DeliveryZonesRepository(
      dataSource: DeliveryZonesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final paymentAccountsRepository = PaymentAccountsRepository(
      dataSource: PaymentAccountsDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final vehiclesRepository = VehiclesRepository(
      dataSource: VehiclesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final pendingOrdersRepository = PendingOrdersRepository(
      dataSource: PendingOrdersDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final clientsRepository = ClientsRepository(
      service: ClientService(
        firestore: authRepository.firestore,
      ),
    );

    final analyticsRepository = AnalyticsRepository(
      service: AnalyticsService(
        firestore: authRepository.firestore,
      ),
    );

    final transactionsDataSource = TransactionsDataSource(
      firestore: authRepository.firestore,
    );
    
    final transactionsRepository = TransactionsRepository(
      dataSource: transactionsDataSource,
    );
    
    final paymentAccountsDataSource = PaymentAccountsDataSource(
      firestore: authRepository.firestore,
    );
    
    final expenseSubCategoriesRepository = ExpenseSubCategoriesRepository(
      dataSource: ExpenseSubCategoriesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final dmSettingsRepository = DmSettingsRepository(
      dataSource: DmSettingsDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final employeeWagesRepository = EmployeeWagesRepository(
      dataSource: EmployeeWagesDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final clientLedgerRepository = ClientLedgerRepository(
      dataSource: ClientLedgerDataSource(
        firestore: authRepository.firestore,
      ),
    );

    final scheduledTripsRepository = ScheduledTripsRepository(
      dataSource: ScheduledTripsDataSource(firestore: authRepository.firestore),
    );

    // Initialize Firebase Functions - matching web app pattern exactly
    final deliveryMemoRepository = DeliveryMemoRepository(
      dataSource: DeliveryMemoDataSource(
        firestore: authRepository.firestore,
        functions: FirebaseFunctions.instanceFor(region: 'asia-south1'),
      ),
    );

    final qrCodeService = QrCodeService();
    final dmPrintService = DmPrintService(
      dmSettingsRepository: dmSettingsRepository,
      paymentAccountsRepository: paymentAccountsRepository,
      qrCodeService: qrCodeService,
    );

    final router = buildRouter();
    return CallerOverlayBootstrap(
      child: MultiRepositoryProvider(
        providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: organizationRepository),
        RepositoryProvider.value(value: rolesRepository),
        RepositoryProvider.value(value: appAccessRolesRepository),
        RepositoryProvider.value(value: productsRepository),
        RepositoryProvider.value(value: employeesRepository),
        RepositoryProvider.value(value: vendorsRepository),
        RepositoryProvider.value(value: usersRepository),
        RepositoryProvider.value(value: deliveryZonesRepository),
        RepositoryProvider.value(value: paymentAccountsRepository),
        RepositoryProvider.value(value: vehiclesRepository),
        RepositoryProvider.value(value: pendingOrdersRepository),
        RepositoryProvider.value(value: clientsRepository),
        RepositoryProvider.value(value: analyticsRepository),
        RepositoryProvider.value(value: transactionsRepository),
        RepositoryProvider.value(value: employeeWagesRepository),
        RepositoryProvider.value(value: clientLedgerRepository),
        RepositoryProvider.value(value: scheduledTripsRepository),
        RepositoryProvider.value(value: deliveryMemoRepository),
        RepositoryProvider.value(value: qrCodeService),
        RepositoryProvider.value(value: dmPrintService),
        RepositoryProvider.value(value: transactionsDataSource),
        RepositoryProvider.value(value: paymentAccountsDataSource),
        RepositoryProvider.value(value: expenseSubCategoriesRepository),
        RepositoryProvider.value(value: dmSettingsRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(
              authRepository: authRepository,
            )..add(const AuthStatusRequested()),
          ),
          BlocProvider(create: (_) => OrganizationContextCubit()),
          BlocProvider(
            create: (_) => OrgSelectorCubit(
              repository: organizationRepository,
            ),
          ),
          BlocProvider(
            lazy: false,
            create: (context) => AppInitializationCubit(
              authRepository: authRepository,
              orgContextCubit: context.read<OrganizationContextCubit>(),
              orgSelectorCubit: context.read<OrgSelectorCubit>(),
              appAccessRolesRepository: appAccessRolesRepository,
            ),
          ),
        ],
          child: MaterialApp.router(
            title: 'Dash Mobile',
            theme: buildDashTheme(),
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              if (kDebugMode) {
                debugPrint('[MaterialApp.builder] Called with child: ${child != null ? child.runtimeType : "null"}');
              }
              
              // Ensure MediaQuery has a valid textScaler to prevent configuration ID errors
              // Always wrap with a safe textScaler to avoid the -2147483648 configuration ID error
              final mediaQuery = MediaQuery.maybeOf(context);
              final safeTextScaler = const TextScaler.linear(1.0);
              
              Widget wrappedChild = child ?? const SizedBox.shrink();
              
              // Always wrap with MediaQuery that has a safe textScaler
              // This prevents the "incorrect configuration id: -2147483648" error
              if (mediaQuery != null) {
                wrappedChild = MediaQuery(
                  data: mediaQuery.copyWith(textScaler: safeTextScaler),
                  child: wrappedChild,
                );
              }
              
              final wrapped = TexturedBackground(
                pattern: BackgroundPattern.dotted, // More visible pattern
                opacity: 1.0, // Maximum visibility for testing
                debugMode: kDebugMode, // Enable debug in debug mode
                child: wrappedChild,
              );
              if (kDebugMode) {
                debugPrint('[MaterialApp.builder] Returning TexturedBackground widget');
              }
              return wrapped;
            },
          ),
        ),
      ),
    );
  }
}
