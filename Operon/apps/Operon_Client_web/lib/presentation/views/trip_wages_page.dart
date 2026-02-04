import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:dash_web/presentation/blocs/org_context/org_context_cubit.dart';
import 'package:dash_web/presentation/blocs/trip_wages/trip_wages_cubit.dart';
import 'package:dash_web/presentation/blocs/trip_wages/trip_wages_state.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_cubit.dart';
import 'package:dash_web/presentation/widgets/section_workspace_layout.dart';
import 'package:dash_web/presentation/widgets/trip_wage_employee_selection_dialog.dart';
import 'package:dash_web/presentation/widgets/weekly_ledger_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TripWagesPage extends StatelessWidget {
  const TripWagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    
    if (organization == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('No organization selected'),
              const SizedBox(height: 16),
              DashButton(
                label: 'Select Organization',
                onPressed: () => context.go('/org-selection'),
              ),
            ],
          ),
        ),
      );
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TripWagesCubit(
            repository: context.read<TripWagesRepository>(),
            deliveryMemoRepository: context.read<DeliveryMemoRepository>(),
            organizationId: organization.id,
            employeesRepository: context.read<EmployeesRepository>(),
            wageSettingsRepository: context.read<WageSettingsRepository>(),
            wageCalculationService: WageCalculationService(
              employeeWagesDataSource: EmployeeWagesDataSource(),
              productionBatchesDataSource: ProductionBatchesDataSource(),
              tripWagesDataSource: TripWagesDataSource(),
              employeeAttendanceDataSource: EmployeeAttendanceDataSource(),
            ),
          )..loadWageSettings(),
        ),
        BlocProvider(
          create: (context) => WeeklyLedgerCubit(
            productionBatchesRepository: context.read<ProductionBatchesRepository>(),
            tripWagesRepository: context.read<TripWagesRepository>(),
            employeesRepository: context.read<EmployeesRepository>(),
            deliveryMemoRepository: context.read<DeliveryMemoRepository>(),
            employeeWagesRepository: context.read<EmployeeWagesRepository>(),
            organizationId: organization.id,
          ),
        ),
      ],
      child: SectionWorkspaceLayout(
        panelTitle: 'Trip Wages',
        currentIndex: -1,
        onNavTap: (index) => context.go('/home?section=$index'),
        child: const _TripWagesContent(),
      ),
    );
  }
}

class _TripWagesContent extends StatefulWidget {
  const _TripWagesContent();

  @override
  State<_TripWagesContent> createState() => _TripWagesContentState();
}

class _TripWagesContentState extends State<_TripWagesContent> {
  DateTime _selectedDate = DateTime.now();
  int _sectionIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<TripWagesCubit>();
      cubit.loadActiveDMsForDate(_selectedDate);
      cubit.loadEmployeesByRole('Loader');
      cubit.loadWageSettings();
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      context.read<TripWagesCubit>().loadActiveDMsForDate(_selectedDate);
    }
  }

  Future<void> _handleDMCardTap(Map<String, dynamic> dm) async {
    final cubit = context.read<TripWagesCubit>();
    final state = cubit.state;
    
    // Ensure employees and wage settings are loaded
    if (state.loadingEmployees.isEmpty) {
      await cubit.loadEmployeesByRole('Loader');
    }
    if (state.wageSettings == null) {
      await cubit.loadWageSettings();
    }

    final wageSettings = state.wageSettings;
    if (wageSettings == null || !wageSettings.enabled) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Wage settings are not enabled', isError: true);
      }
      return;
    }

    // Find loading/unloading method
    final loadingUnloadingMethods = wageSettings.calculationMethods.values
        .where((m) => m.enabled && m.methodType == WageMethodType.loadingUnloading)
        .toList();

    if (loadingUnloadingMethods.isEmpty) {
      if (mounted) {
        DashSnackbar.show(context, message: 'No loading/unloading wage method found', isError: true);
      }
      return;
    }

    final method = loadingUnloadingMethods.first;
    final methodId = method.methodId;

    // Get quantity from DM
    final items = dm['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      if (mounted) {
        DashSnackbar.show(context, message: 'DM has no items', isError: true);
      }
      return;
    }

    final firstItem = items[0] as Map<String, dynamic>;
    final quantity = firstItem['fixedQuantityPerTrip'] as int? ?? 0;

    // Calculate total wage for display
    final totalWage = cubit.calculateWageForQuantity(quantity, method);

    // Get existing trip wage data if it exists
    final existingTripWage = dm['tripWage'] as TripWage?;
    final existingLoadingIds = existingTripWage?.loadingEmployeeIds ?? [];
    final existingUnloadingIds = existingTripWage?.unloadingEmployeeIds ?? [];
    final sameEmployees = existingTripWage != null && 
        existingLoadingIds.length == existingUnloadingIds.length &&
        existingLoadingIds.toSet().containsAll(existingUnloadingIds) &&
        existingUnloadingIds.toSet().containsAll(existingLoadingIds);

    // Show employee selection dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => TripWageEmployeeSelectionDialog(
        employees: state.loadingEmployees,
        totalWage: totalWage,
        loadingEmployeeIds: existingLoadingIds,
        unloadingEmployeeIds: existingUnloadingIds,
        sameEmployees: sameEmployees,
      ),
    );

    if (result != null && mounted) {
      final loadingEmployeeIds = List<String>.from(result['loadingEmployeeIds'] ?? []);
      final unloadingEmployeeIds = List<String>.from(result['unloadingEmployeeIds'] ?? []);
      
      if (loadingEmployeeIds.isEmpty && unloadingEmployeeIds.isEmpty) {
        return;
      }

      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        final createdBy = currentUser?.uid ?? 'system';

        // Check if trip wage already exists - update instead of create
        final hasTripWage = dm['hasTripWage'] == true;
        final tripWageId = dm['tripWageId'] as String?;
        
        if (hasTripWage && tripWageId != null) {
          // Update existing trip wage
          await cubit.updateTripWage(
            tripWageId,
            {
              'loadingEmployeeIds': loadingEmployeeIds,
              'unloadingEmployeeIds': unloadingEmployeeIds,
              'status': TripWageStatus.recorded.name,
              'updatedAt': DateTime.now(),
            },
          );
          // Recalculate and process
          await cubit.calculateTripWage(tripWageId);
          await cubit.processTripWage(tripWageId, DateTime.now());
        } else {
          // Create new trip wage (already calculates wages internally)
          final newTripWageId = await cubit.createTripWageFromDM(
            dm: dm,
            methodId: methodId,
            loadingEmployeeIds: loadingEmployeeIds,
            unloadingEmployeeIds: unloadingEmployeeIds,
            createdBy: createdBy,
            sameEmployees: result['sameEmployees'] ?? false,
          );
          
          // Ensure trip wage document is fully written before processing
          // Wait a moment for Firestore write to complete
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Update status to calculated since wages are already calculated in createTripWageFromDM
          await cubit.updateTripWage(newTripWageId, {
            'status': TripWageStatus.calculated.name,
          });
          
          // Wait a bit more to ensure status update is visible before processing
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Process the newly created trip wage (creates transactions)
          await cubit.processTripWage(newTripWageId, DateTime.now());
        }

        // Reload active DMs to update the trip wage status
        await cubit.loadActiveDMsForDate(_selectedDate);
        
        if (mounted) {
          DashSnackbar.show(
            context,
            message: hasTripWage ? 'Trip wage updated successfully' : 'Trip wage created successfully',
            isError: false,
          );
        }

        if (mounted) {
          DashSnackbar.show(context, message: 'Trip wage created successfully', isError: false);
        }
      } catch (e) {
        if (mounted) {
          DashSnackbar.show(context, message: 'Failed to create trip wage: $e', isError: true);
        }
      }
    }
  }

  Future<void> _handleDiscardTripWage(BuildContext context, String tripWageId) async {
    // Validate tripWageId before proceeding
    if (tripWageId.isEmpty) {
      if (context.mounted) {
        DashSnackbar.show(context, message: 'Error: Invalid trip wage ID', isError: true);
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AuthColors.surface,
        title: const Text(
          'Discard Trip Wage?',
          style: TextStyle(color: AuthColors.textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete the trip wage and revert all related transactions and attendance records.',
              style: TextStyle(color: AuthColors.textSub),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_outlined,
                    color: Colors.orange,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          DashButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
            variant: DashButtonVariant.text,
          ),
          DashButton(
            label: 'Discard',
            onPressed: () => Navigator.of(dialogContext).pop(true),
            isDestructive: true,
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final cubit = context.read<TripWagesCubit>();
    try {
      await cubit.deleteTripWage(tripWageId);
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Trip wage discarded successfully. Wages and attendance have been reverted.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Error discarding trip wage: $e', isError: true);
      }
    }
  }

  double _calculateWageForDM(Map<String, dynamic> dm, TripWagesCubit cubit) {
    final state = cubit.state;
    final wageSettings = state.wageSettings;
    
    if (wageSettings == null || !wageSettings.enabled) {
      return 0.0;
    }

    final loadingUnloadingMethods = wageSettings.calculationMethods.values
        .where((m) => m.enabled && m.methodType == WageMethodType.loadingUnloading)
        .toList();

    if (loadingUnloadingMethods.isEmpty) {
      return 0.0;
    }

    final method = loadingUnloadingMethods.first;

    final items = dm['items'] as List<dynamic>? ?? [];
    if (items.isEmpty) {
      return 0.0;
    }

    final firstItem = items[0] as Map<String, dynamic>;
    final quantity = firstItem['fixedQuantityPerTrip'] as int? ?? 0;

    return cubit.calculateWageForQuantity(quantity, method);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripWagesCubit, TripWagesState>(
      builder: (context, state) {
        if (state.status == ViewStatus.loading && state.activeDMs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ViewStatus.failure && state.message != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Error: ${state.message}'),
                const SizedBox(height: 16),
                DashButton(
                  label: 'Retry',
                  onPressed: () => context.read<TripWagesCubit>().loadActiveDMsForDate(_selectedDate),
                ),
              ],
            ),
          );
        }

        final cubit = context.read<TripWagesCubit>();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: FloatingNavBar(
                    items: const [
                      NavBarItem(
                        icon: Icons.local_shipping_outlined,
                        label: 'Trip Wages',
                        heroTag: 'trip_wages_main',
                      ),
                      NavBarItem(
                        icon: Icons.calendar_view_week_outlined,
                        label: 'Weekly Ledger',
                        heroTag: 'trip_wages_weekly_ledger',
                      ),
                    ],
                    currentIndex: _sectionIndex,
                    onItemTapped: (index) => setState(() => _sectionIndex = index),
                  ),
                ),
              ),
            ),
            if (_sectionIndex == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AuthColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AuthColors.textMain.withValues(alpha: 0.15),
                            ),
                          ),
                          child: InkWell(
                            onTap: _selectDate,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: AuthColors.textSub,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: const TextStyle(
                                      color: AuthColors.textMain,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_drop_down,
                                    color: AuthColors.textSub,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                builder: (context, constraints) {
                  return SizedBox(
                    height: constraints.maxHeight.isFinite 
                        ? constraints.maxHeight 
                        : MediaQuery.of(context).size.height - 200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // DM Cards (2/3 width)
                    Expanded(
                      flex: 2,
                      child: state.activeDMs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(48),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_shipping_outlined,
                                      size: 64,
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No active delivery memos for this date',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${state.activeDMs.length} DMs found',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                // Cap displayed cards to avoid browser tab crash on massive days
                                const maxDisplayedDMs = 50;
                                final displayedDMs = state.activeDMs.take(maxDisplayedDMs).toList();
                                final hasMore = state.activeDMs.length > maxDisplayedDMs;
                                // Calculate number of columns based on available width (2/3 of total)
                                final availableWidth = constraints.maxWidth;
                                final crossAxisCount = (availableWidth / 400).floor().clamp(1, 3);
                                final cardWidth = (availableWidth - (crossAxisCount - 1) * 16) / crossAxisCount;
                                
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (hasMore)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Text(
                                            'Showing first $maxDisplayedDMs of ${state.activeDMs.length} delivery memos',
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      Wrap(
                                        spacing: 16,
                                        runSpacing: 16,
                                        children: displayedDMs.map((dm) {
                                          final calculatedWage = _calculateWageForDM(dm, cubit);
                                          final hasTripWage = dm['hasTripWage'] == true;
                                          final tripWageStatus = dm['tripWageStatus'] as String?;
                                          final tripWageId = dm['tripWageId'] as String?;
                                          final tripWage = dm['tripWage'] as TripWage?;
                                          final loadingEmployeeIds = dm['loadingEmployeeIds'] as List<String>? ?? [];
                                          final unloadingEmployeeIds = dm['unloadingEmployeeIds'] as List<String>? ?? [];
                                          
                                          return SizedBox(
                                            width: cardWidth,
                                            child: _DMCard(
                                              dm: dm,
                                              calculatedWage: calculatedWage,
                                              hasTripWage: hasTripWage,
                                              tripWageStatus: tripWageStatus,
                                              tripWageId: tripWageId,
                                              tripWage: tripWage,
                                              loadingEmployeeIds: loadingEmployeeIds,
                                              unloadingEmployeeIds: unloadingEmployeeIds,
                                              availableEmployees: state.loadingEmployees,
                                              onTap: () => _handleDMCardTap(dm),
                                              onDiscard: hasTripWage && tripWageId != null
                                                  ? () => _handleDiscardTripWage(context, tripWageId)
                                                  : null,
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    const SizedBox(width: 24),
                    
                    // Summary Table (1/3 width - fixed)
                    Expanded(
                      flex: 1,
                      child: _WageSummaryTable(
                        activeDMs: state.activeDMs,
                        availableEmployees: state.loadingEmployees,
                      ),
                    ),
                      ],
                    ),
                  );
                },
              ),
                  ],
                ),
              ),
            if (_sectionIndex != 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: const _WeeklyLedgerBlock(),
              ),
          ],
        );
      },
    );
  }
}

class _DMCard extends StatelessWidget {
  const _DMCard({
    required this.dm,
    required this.calculatedWage,
    required this.hasTripWage,
    this.tripWageStatus,
    this.tripWageId,
    this.tripWage,
    this.loadingEmployeeIds = const [],
    this.unloadingEmployeeIds = const [],
    this.availableEmployees = const [],
    required this.onTap,
    this.onDiscard,
  });

  final Map<String, dynamic> dm;
  final double calculatedWage;
  final bool hasTripWage;
  final String? tripWageStatus;
  final String? tripWageId;
  final TripWage? tripWage;
  final List<String> loadingEmployeeIds;
  final List<String> unloadingEmployeeIds;
  final List<OrganizationEmployee> availableEmployees;
  final VoidCallback onTap;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final dmNumber = dm['dmNumber'] ?? 'N/A';
    final clientName = dm['clientName'] ?? 'Unknown Client';
    final deliveryZone = dm['deliveryZone'] as Map<String, dynamic>?;
    final region = deliveryZone?['region'] ?? deliveryZone?['city_name'] ?? 'N/A';
    final driverName = dm['driverName'] ?? 'N/A';
    final vehicleNumber = dm['vehicleNumber'] ?? 'N/A';
    
    final items = dm['items'] as List<dynamic>? ?? [];
    final fixedQuantity = items.isNotEmpty && items[0] is Map<String, dynamic>
        ? ((items[0] as Map<String, dynamic>)['fixedQuantityPerTrip'] as num?)?.toInt() ?? 0
        : 0;

    // Get employee names
    final loadingEmployeeNames = loadingEmployeeIds
        .map((id) {
          final employee = availableEmployees.where((e) => e.id == id).firstOrNull;
          return employee?.name ?? 'Unknown';
        })
        .toList();
    
    final unloadingEmployeeNames = unloadingEmployeeIds
        .map((id) {
          final employee = availableEmployees.where((e) => e.id == id).firstOrNull;
          return employee?.name ?? 'Unknown';
        })
        .toList();

    // Get wage breakdown
    final totalWages = tripWage?.totalWages ?? calculatedWage;
    final loadingWages = tripWage?.loadingWages ?? (calculatedWage / 2);
    final unloadingWages = tripWage?.unloadingWages ?? (calculatedWage / 2);
    final loadingWagePerEmployee = tripWage?.loadingWagePerEmployee ?? 
        (loadingEmployeeIds.isNotEmpty ? loadingWages / loadingEmployeeIds.length : 0.0);
    final unloadingWagePerEmployee = tripWage?.unloadingWagePerEmployee ?? 
        (unloadingEmployeeIds.isNotEmpty ? unloadingWages / unloadingEmployeeIds.length : 0.0);

    // Determine status for workflow progress
    TripWageStatus? status;
    if (tripWageStatus != null) {
      status = TripWageStatus.values.firstWhere(
        (e) => e.name == tripWageStatus,
        orElse: () => TripWageStatus.recorded,
      );
    }

    final statusColor = hasTripWage ? _getStatusColor(status ?? TripWageStatus.recorded) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AuthColors.textMainWithOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasTripWage
                    ? (statusColor ?? AuthColors.legacyAccent).withValues(alpha: 0.5)
                    : AuthColors.textMainWithOpacity(0.2),
                width: hasTripWage ? 2 : 1,
              ),
              boxShadow: hasTripWage && statusColor != null
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with DM number and status
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            'DM #$dmNumber',
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (hasTripWage && status != null) ...[
                            const SizedBox(width: 8),
                            _StatusBadge(status: status),
                          ],
                        ],
                      ),
                    ),
                    if (totalWages > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AuthColors.legacyAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '₹${totalWages.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AuthColors.legacyAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Workflow progress (if trip wage exists)
                if (hasTripWage && status != null) ...[
                  _WorkflowProgress(status: status),
                  const SizedBox(height: 16),
                ],
                
                // Basic info
                Row(
                  children: [
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.business,
                        label: 'Client',
                        value: clientName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.location_on,
                        label: 'Region',
                        value: region,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.person,
                        label: 'Driver',
                        value: driverName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoItem(
                        icon: Icons.local_shipping,
                        label: 'Vehicle',
                        value: vehicleNumber,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Quantity
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AuthColors.textMainWithOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 18, color: AuthColors.textMainWithOpacity(0.7)),
                      const SizedBox(width: 8),
                      Text(
                        'Quantity: $fixedQuantity units',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Employee and wage details (if trip wage exists)
                if (hasTripWage && (loadingEmployeeIds.isNotEmpty || unloadingEmployeeIds.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AuthColors.textDisabled, height: 1),
                  const SizedBox(height: 12),
                  
                  // Employees section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.people_outline, size: 18, color: AuthColors.textMainWithOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (loadingEmployeeIds.isNotEmpty) ...[
                              Text(
                                '${loadingEmployeeNames.take(2).join(', ')}${loadingEmployeeNames.length > 2 ? ' +${loadingEmployeeNames.length - 2}' : ''}',
                                style: TextStyle(
                                  color: AuthColors.textMainWithOpacity(0.8),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (unloadingEmployeeIds.isNotEmpty && 
                                  !_areSameEmployees(loadingEmployeeIds, unloadingEmployeeIds))
                                const SizedBox(height: 4),
                            ],
                            if (unloadingEmployeeIds.isNotEmpty && 
                                !_areSameEmployees(loadingEmployeeIds, unloadingEmployeeIds))
                              Text(
                                '${unloadingEmployeeNames.take(2).join(', ')}${unloadingEmployeeNames.length > 2 ? ' +${unloadingEmployeeNames.length - 2}' : ''}',
                                style: TextStyle(
                                  color: AuthColors.textMainWithOpacity(0.8),
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  // Individual Employee Wage Breakdown (if calculated)
                  if (tripWage?.totalWages != null && tripWage?.loadingWagePerEmployee != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total: ₹${tripWage!.totalWages!.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Per Employee: ₹${(loadingWagePerEmployee + unloadingWagePerEmployee).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: AuthColors.textDisabled, height: 1),
                          const SizedBox(height: 8),
                          // Individual employee breakdown
                          ...loadingEmployeeNames.asMap().entries.map((entry) {
                            final index = entry.key;
                            final employeeName = entry.value;
                            final employeeId = loadingEmployeeIds[index];
                            final isAlsoUnloading = unloadingEmployeeIds.contains(employeeId);
                            final employeeTotalWage = loadingWagePerEmployee + 
                                (isAlsoUnloading ? unloadingWagePerEmployee : 0.0);
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      employeeName,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Row(
                                    children: [
                                      if (isAlsoUnloading) ...[
                                        Text(
                                          'L: ₹${loadingWagePerEmployee.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'U: ₹${unloadingWagePerEmployee.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                      ] else
                                        Text(
                                          'L: ₹${loadingWagePerEmployee.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                            fontSize: 11,
                                          ),
                                        ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '₹${employeeTotalWage.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                          // Show unloading-only employees if different
                          if (!_areSameEmployees(loadingEmployeeIds, unloadingEmployeeIds))
                            ...unloadingEmployeeNames
                                .where((name) {
                                  final employeeId = unloadingEmployeeIds[
                                    unloadingEmployeeNames.indexOf(name)
                                  ];
                                  return !loadingEmployeeIds.contains(employeeId);
                                })
                                .map((employeeName) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            employeeName,
                                            style: TextStyle(
                                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Row(
                                          children: [
                                            Text(
                                              'U: ₹${unloadingWagePerEmployee.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '₹${unloadingWagePerEmployee.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (onDiscard != null)
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  // Stop tap propagation to the card
                  onDiscard?.call();
                },
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _areSameEmployees(List<String> list1, List<String> list2) {
    if (list1.length != list2.length) return false;
    final set1 = list1.toSet();
    final set2 = list2.toSet();
    return set1.length == set2.length && set1.every(set2.contains);
  }

  Color _getStatusColor(TripWageStatus status) {
    switch (status) {
      case TripWageStatus.recorded:
        return Colors.orange;
      case TripWageStatus.calculated:
        return AuthColors.info;
      case TripWageStatus.processed:
        return AuthColors.success;
    }
  }

}

class _WageSummaryTable extends StatelessWidget {
  const _WageSummaryTable({
    required this.activeDMs,
    required this.availableEmployees,
  });

  final List<Map<String, dynamic>> activeDMs;
  final List<OrganizationEmployee> availableEmployees;

  /// Calculate cumulative wage summary from all active DMs
  Map<String, Map<String, dynamic>> _calculateWageSummary() {
    final summary = <String, Map<String, dynamic>>{};

    for (final dm in activeDMs) {
      final tripWage = dm['tripWage'] as TripWage?;
      if (tripWage == null) continue;

      final loadingEmployeeIds = tripWage.loadingEmployeeIds;
      final unloadingEmployeeIds = tripWage.unloadingEmployeeIds;
      final loadingWagePerEmployee = tripWage.loadingWagePerEmployee ?? 0.0;
      final unloadingWagePerEmployee = tripWage.unloadingWagePerEmployee ?? 0.0;

      // Get unique set of all employees for this trip wage (for counting)
      final allEmployeeIdsForTrip = <String>{...loadingEmployeeIds, ...unloadingEmployeeIds};

      // Process each unique employee once per trip wage
      for (final employeeId in allEmployeeIdsForTrip) {
        if (!summary.containsKey(employeeId)) {
          final employee = availableEmployees.where((e) => e.id == employeeId).firstOrNull;
          summary[employeeId] = {
            'name': employee?.name ?? 'Unknown',
            'count': 0,
            'totalWage': 0.0,
          };
        }
        
        // Count this trip wage once for the employee (not twice if they do both loading and unloading)
        summary[employeeId]!['count'] = (summary[employeeId]!['count'] as int) + 1;
        
        // Add wages: loading wage if they're in loading, unloading wage if they're in unloading
        if (loadingEmployeeIds.contains(employeeId)) {
          summary[employeeId]!['totalWage'] = 
              (summary[employeeId]!['totalWage'] as double) + loadingWagePerEmployee;
        }
        if (unloadingEmployeeIds.contains(employeeId)) {
          summary[employeeId]!['totalWage'] = 
              (summary[employeeId]!['totalWage'] as double) + unloadingWagePerEmployee;
        }
      }
    }

    return summary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = _calculateWageSummary();
    final summaryList = summary.values.toList()
      ..sort((a, b) => (b['totalWage'] as double).compareTo(a['totalWage'] as double));

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.summarize_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Wage Summary',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Table
          Expanded(
            child: summaryList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No wage data available',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(1.5),
                      },
                      children: [
                        // Table Header
                        TableRow(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            border: Border(
                              bottom: BorderSide(
                                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          children: [
                            _buildTableCell(
                              context,
                              'Employee Name',
                              isHeader: true,
                              alignment: Alignment.centerLeft,
                            ),
                            _buildTableCell(
                              context,
                              'Count',
                              isHeader: true,
                            ),
                            _buildTableCell(
                              context,
                              'Total Wage',
                              isHeader: true,
                            ),
                          ],
                        ),
                        // Table Rows
                        ...summaryList.map((entry) {
                          final name = entry['name'] as String;
                          final count = entry['count'] as int;
                          final totalWage = entry['totalWage'] as double;

                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: theme.colorScheme.outline.withValues(alpha: 0.1),
                                ),
                              ),
                            ),
                            children: [
                              _buildTableCell(
                                context,
                                name,
                                alignment: Alignment.centerLeft,
                              ),
                              _buildTableCell(
                                context,
                                count.toString(),
                              ),
                              _buildTableCell(
                                context,
                                '₹${totalWage.toStringAsFixed(2)}',
                                isAmount: true,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
          ),
          
          // Footer with totals
          if (summaryList.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Employees:',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${summaryList.length}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Total Wages:',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '₹${summaryList.fold<double>(0.0, (sum, entry) => sum + (entry['totalWage'] as double)).toStringAsFixed(2)}',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableCell(
    BuildContext context,
    String text, {
    bool isHeader = false,
    bool isAmount = false,
    Alignment alignment = Alignment.center,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: TextStyle(
            color: isHeader
                ? theme.colorScheme.onSurface.withValues(alpha: 0.9)
                : isAmount
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: isHeader ? 13 : 12,
            fontWeight: isHeader || isAmount ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final TripWageStatus status;

  Color get _statusColor {
    switch (status) {
      case TripWageStatus.recorded:
        return Colors.orange;
      case TripWageStatus.calculated:
        return AuthColors.info;
      case TripWageStatus.processed:
        return AuthColors.success;
    }
  }

  String get _statusLabel {
    switch (status) {
      case TripWageStatus.recorded:
        return 'Recorded';
      case TripWageStatus.calculated:
        return 'Calculated';
      case TripWageStatus.processed:
        return 'Processed';
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case TripWageStatus.recorded:
        return Icons.edit_outlined;
      case TripWageStatus.calculated:
        return Icons.calculate_outlined;
      case TripWageStatus.processed:
        return Icons.done_all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcon, size: 14, color: _statusColor),
          const SizedBox(width: 4),
          Text(
            _statusLabel,
            style: TextStyle(
              color: _statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowProgress extends StatelessWidget {
  const _WorkflowProgress({required this.status});

  final TripWageStatus status;

  int get _currentStep {
    switch (status) {
      case TripWageStatus.recorded:
        return 1;
      case TripWageStatus.calculated:
        return 2;
      case TripWageStatus.processed:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [
      _WorkflowStep(label: 'Recorded', completed: _currentStep >= 1),
      _WorkflowStep(label: 'Calculated', completed: _currentStep >= 2),
      _WorkflowStep(label: 'Processed', completed: _currentStep >= 3),
    ];

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.completed
                            ? AuthColors.legacyAccent
                            : AuthColors.textMainWithOpacity(0.1),
                        border: Border.all(
                          color: step.completed
                              ? AuthColors.legacyAccent
                              : AuthColors.textMainWithOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: step.completed
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: AuthColors.textMain,
                            )
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.label,
                      style: TextStyle(
                        color: step.completed
                            ? AuthColors.textMain
                            : AuthColors.textMainWithOpacity(0.5),
                        fontSize: 9,
                        fontWeight: step.completed ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: step.completed
                          ? AuthColors.legacyAccent
                          : AuthColors.textMainWithOpacity(0.1),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WorkflowStep {
  const _WorkflowStep({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AuthColors.textMainWithOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AuthColors.textMainWithOpacity(0.6),
                    fontSize: 10,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyLedgerBlock extends StatelessWidget {
  const _WeeklyLedgerBlock();

  @override
  Widget build(BuildContext context) {
    final orgState = context.watch<OrganizationContextCubit>().state;
    final organization = orgState.organization;
    if (organization == null) return const SizedBox.shrink();
    final cubit = context.read<WeeklyLedgerCubit>();
    return WeeklyLedgerSection(
      organizationId: organization.id,
      weeklyLedgerCubit: cubit,
    );
  }
}
