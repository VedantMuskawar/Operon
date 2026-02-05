import 'package:core_services/core_services.dart';
import 'package:dash_web/config/app_router.dart';
import 'package:dash_web/config/app_theme.dart';
import 'package:core_datasources/core_datasources.dart'
    hide ScheduledTripsDataSource, ScheduledTripsRepository;
import 'package:dash_web/data/datasources/bonus_settings_data_source.dart';
import 'package:dash_web/data/datasources/employees_data_source.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/data/datasources/app_access_roles_data_source.dart';
import 'package:dash_web/data/datasources/job_roles_data_source.dart';
import 'package:dash_web/data/datasources/users_data_source.dart';
import 'package:dash_web/data/datasources/clients_data_source.dart';
import 'package:dash_web/data/datasources/pending_orders_data_source.dart';
import 'package:dash_web/data/datasources/scheduled_trips_data_source.dart';
import 'package:dash_web/data/repositories/auth_repository.dart';
import 'package:dash_web/data/repositories/bonus_settings_repository.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/repositories/products_repository.dart';
import 'package:dash_web/data/repositories/raw_materials_repository.dart';
import 'package:dash_web/data/repositories/app_access_roles_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
import 'package:dash_web/data/repositories/user_organization_repository.dart';
import 'package:dash_web/data/repositories/users_repository.dart';
import 'package:dash_web/data/repositories/vehicles_repository.dart';
import 'package:dash_web/data/repositories/delivery_zones_repository.dart';
import 'package:dash_web/data/repositories/clients_repository.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/datasources/analytics_data_source.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';
import 'package:dash_web/data/repositories/scheduled_trips_repository.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/organization_locations_repository.dart';
import 'package:dash_web/data/repositories/geofences_repository.dart';
import 'package:dash_web/data/repositories/notifications_repository.dart';
import 'package:dash_web/data/datasources/organization_location_data_source.dart';
import 'package:dash_web/data/datasources/geofence_data_source.dart';
import 'package:dash_web/data/datasources/notification_data_source.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/blocs/app_initialization/app_initialization_cubit.dart';
import 'package:dash_web/presentation/blocs/auth/auth_bloc.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/org_selector/org_selector_cubit.dart';
import 'package:dash_web/presentation/blocs/analytics_dashboard/analytics_dashboard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class DashWebApp extends StatelessWidget {
  const DashWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => AuthRepositoryImpl(),
        ),
        RepositoryProvider<UserOrganizationRepository>(
          create: (_) => UserOrganizationRepository(),
        ),
        RepositoryProvider<RolesRepository>(
          create: (_) => RolesRepository(
            dataSource: RolesDataSource(),
          ),
        ),
        RepositoryProvider<AppAccessRolesRepository>(
          create: (_) => AppAccessRolesRepository(
            dataSource: AppAccessRolesDataSource(),
          ),
        ),
        RepositoryProvider<JobRolesRepository>(
          create: (_) => JobRolesRepository(
            dataSource: JobRolesDataSource(),
          ),
        ),
        RepositoryProvider<ProductsRepository>(
          create: (_) => ProductsRepository(
            dataSource: ProductsDataSource(),
          ),
        ),
        RepositoryProvider<RawMaterialsRepository>(
          create: (_) => RawMaterialsRepository(
            dataSource: RawMaterialsDataSource(),
          ),
        ),
        RepositoryProvider<PaymentAccountsRepository>(
          create: (_) => PaymentAccountsRepository(
            dataSource: PaymentAccountsDataSource(),
          ),
        ),
        RepositoryProvider<UsersRepository>(
          create: (_) => UsersRepository(
            dataSource: UsersDataSource(),
          ),
        ),
        RepositoryProvider<EmployeesRepository>(
          create: (_) => EmployeesRepository(
            dataSource: EmployeesDataSource(),
          ),
        ),
        RepositoryProvider<VendorsRepository>(
          create: (_) => VendorsRepository(
            dataSource: VendorsDataSource(),
          ),
        ),
        RepositoryProvider<VehiclesRepository>(
          create: (_) => VehiclesRepository(
            dataSource: VehiclesDataSource(),
          ),
        ),
        RepositoryProvider<DeliveryZonesRepository>(
          create: (_) => DeliveryZonesRepository(
            dataSource: DeliveryZonesDataSource(),
          ),
        ),
        RepositoryProvider<AnalyticsRepository>(
          create: (_) => AnalyticsRepository(
            dataSource: AnalyticsDataSource(),
          ),
        ),
        RepositoryProvider<ClientsRepository>(
          create: (_) => ClientsRepository(
            dataSource: ClientsDataSource(),
          ),
        ),
        RepositoryProvider<ClientLedgerRepository>(
          create: (_) => ClientLedgerRepository(
            dataSource: ClientLedgerDataSource(),
          ),
        ),
        RepositoryProvider<PendingOrdersRepository>(
          create: (_) => PendingOrdersRepository(
            dataSource: PendingOrdersDataSource(),
          ),
        ),
        RepositoryProvider<ScheduledTripsRepository>(
          create: (_) => ScheduledTripsRepository(
            dataSource: ScheduledTripsDataSource(),
          ),
        ),
        RepositoryProvider<DeliveryMemoRepository>(
          create: (_) => DeliveryMemoRepository(
            dataSource: DeliveryMemoDataSource(
              functions: FirebaseFunctions.instanceFor(region: 'us-central1'),
            ),
          ),
        ),
        RepositoryProvider<EmployeeWagesRepository>(
          create: (_) => EmployeeWagesRepository(
            dataSource: EmployeeWagesDataSource(),
          ),
        ),
        RepositoryProvider<BonusSettingsRepository>(
          create: (_) => BonusSettingsRepository(
            dataSource: BonusSettingsDataSource(),
          ),
        ),
        RepositoryProvider<TransactionsRepository>(
          create: (_) => TransactionsRepository(
            dataSource: TransactionsDataSource(),
          ),
        ),
        RepositoryProvider<ExpenseSubCategoriesRepository>(
          create: (_) => ExpenseSubCategoriesRepository(
            dataSource: ExpenseSubCategoriesDataSource(),
          ),
        ),
        RepositoryProvider<WageSettingsRepository>(
          create: (_) => WageSettingsRepository(
            dataSource: WageSettingsDataSource(),
          ),
        ),
        RepositoryProvider<ProductionBatchesRepository>(
          create: (_) => ProductionBatchesRepository(
            dataSource: ProductionBatchesDataSource(),
          ),
        ),
        RepositoryProvider<ProductionBatchTemplatesRepository>(
          create: (_) => ProductionBatchTemplatesRepository(
            dataSource: ProductionBatchTemplatesDataSource(),
          ),
        ),
        RepositoryProvider<TripWagesRepository>(
          create: (_) => TripWagesRepository(
            dataSource: TripWagesDataSource(),
          ),
        ),
        RepositoryProvider<DmSettingsRepository>(
          create: (_) => DmSettingsRepository(
            dataSource: DmSettingsDataSource(),
          ),
        ),
        RepositoryProvider<QrCodeService>(
          create: (_) => QrCodeService(),
        ),
        RepositoryProvider<DmPrintService>(
          create: (context) => DmPrintService(
            dmSettingsRepository: context.read<DmSettingsRepository>(),
            paymentAccountsRepository: context.read<PaymentAccountsRepository>(),
            qrCodeService: context.read<QrCodeService>(),
          ),
        ),
        RepositoryProvider<OrganizationLocationsRepository>(
          create: (_) => OrganizationLocationsRepository(
            dataSource: OrganizationLocationDataSource(),
          ),
        ),
        RepositoryProvider<GeofencesRepository>(
          create: (_) => GeofencesRepository(
            dataSource: GeofenceDataSource(),
          ),
        ),
        RepositoryProvider<NotificationsRepository>(
          create: (_) => NotificationsRepository(
            dataSource: NotificationDataSource(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            )..add(const AuthStatusRequested()),
          ),
          BlocProvider<OrganizationContextCubit>(
            create: (_) => OrganizationContextCubit(),
          ),
          BlocProvider<OrgSelectorCubit>(
            create: (context) => OrgSelectorCubit(
              repository: context.read<UserOrganizationRepository>(),
            ),
          ),
          BlocProvider<AppInitializationCubit>(
            lazy: false,
            create: (context) => AppInitializationCubit(
              authRepository: context.read<AuthRepository>(),
              orgContextCubit: context.read<OrganizationContextCubit>(),
              orgSelectorCubit: context.read<OrgSelectorCubit>(),
              appAccessRolesRepository: context.read<AppAccessRolesRepository>(),
            ),
          ),
          BlocProvider<AnalyticsDashboardCubit>(
            create: (context) => AnalyticsDashboardCubit(
              analyticsRepository: context.read<AnalyticsRepository>(),
            ),
          ),
        ],
        child: Builder(
          builder: (context) {
            final router = buildRouter();

            return BlocListener<AppInitializationCubit, AppInitializationState>(
              listener: (context, state) {
                // Handle navigation at app level for hot restart cases
                if (state.status == AppInitializationStatus.contextRestored) {
                  final orgState = context.read<OrganizationContextCubit>().state;
                  if (orgState.hasSelection) {
                    final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
                    
                    // Check if the current route is NOT home AND is NOT a print route
                    // This prevents the app from hijacking the /print-dm route during initialization
                    if (currentRoute != '/home' && !currentRoute.startsWith('/print-dm')) {
                      router.go('/home');
                    }
                  }
                }
              },
              child: Builder(
                builder: (context) {
                  // On hot restart, ensure initialization runs even if we're not on splash
                  // This handles the case where the router preserves the previous route
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (context.mounted) {
                      final initState = context.read<AppInitializationCubit>().state;
                      
                      // If initialization hasn't started, trigger it
                      if (initState.status == AppInitializationStatus.initial) {
                        context.read<AuthBloc>().add(const AuthStatusRequested());
                        context.read<AppInitializationCubit>().initialize();
                      } else if (initState.status == AppInitializationStatus.contextRestored) {
                        // If already restored, check if we need to navigate
                        final orgState = context.read<OrganizationContextCubit>().state;
                        if (orgState.hasSelection) {
                          try {
                            final router = GoRouter.maybeOf(context);
                            if (router != null) {
                              final currentRoute = router.routerDelegate.currentConfiguration.uri.path;
                              // Only redirect from splash or root, not from print routes
                              if ((currentRoute == '/splash' || currentRoute == '/') && 
                                  !currentRoute.startsWith('/print-dm')) {
                                context.go('/home');
                              }
                            }
                          } catch (_) {
                            // GoRouter not available yet, skip navigation
                          }
                        }
                      }
                    }
                  });
                  
                  return MaterialApp.router(
                    title: 'Dash Web',
                    theme: buildDashTheme(),
                    routerConfig: router,
                    debugShowCheckedModeBanner: false,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
