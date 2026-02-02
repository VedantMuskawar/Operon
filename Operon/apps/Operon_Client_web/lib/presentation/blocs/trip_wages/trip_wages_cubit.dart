import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'trip_wages_state.dart';

class TripWagesCubit extends Cubit<TripWagesState> {
  TripWagesCubit({
    required TripWagesRepository repository,
    required DeliveryMemoRepository deliveryMemoRepository,
    required String organizationId,
    EmployeesRepository? employeesRepository,
    WageSettingsRepository? wageSettingsRepository,
    WageCalculationService? wageCalculationService,
  })  : _repository = repository,
        _deliveryMemoRepository = deliveryMemoRepository,
        _organizationId = organizationId,
        _employeesRepository = employeesRepository,
        _wageSettingsRepository = wageSettingsRepository,
        _wageCalculationService = wageCalculationService,
        super(const TripWagesState());

  final TripWagesRepository _repository;
  final DeliveryMemoRepository _deliveryMemoRepository;
  final String _organizationId;
  final EmployeesRepository? _employeesRepository;
  final WageSettingsRepository? _wageSettingsRepository;
  final WageCalculationService? _wageCalculationService;
  StreamSubscription<List<TripWage>>? _tripWagesSubscription;

  @override
  Future<void> close() {
    _tripWagesSubscription?.cancel();
    return super.close();
  }

  /// Load trip wages
  Future<void> loadTripWages({
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final tripWages = await _repository.fetchTripWages(
        _organizationId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        methodId: methodId,
        dmId: dmId,
        limit: limit,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        tripWages: tripWages,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading trip wages: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load trip wages: ${e.toString()}',
      ));
    }
  }

  /// Watch trip wages stream for real-time updates
  void watchTripWages({
    TripWageStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    String? dmId,
    int? limit,
  }) {
    _tripWagesSubscription?.cancel();
    _tripWagesSubscription = _repository
        .watchTripWages(
      _organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      dmId: dmId,
      limit: limit,
    )
        .listen(
      (tripWages) {
        emit(state.copyWith(
          status: ViewStatus.success,
          tripWages: tripWages,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint('[TripWagesCubit] Error in trip wages stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load trip wages: ${error.toString()}',
        ));
      },
    );
  }

  /// Load returned delivery memos (for assignment)
  Future<void> loadReturnedDMs() async {
    try {
      // Get all active DMs (stream first value)
      final memos = await _deliveryMemoRepository
          .watchDeliveryMemos(
            organizationId: _organizationId,
            status: 'active',
          )
          .first;

      // Filter to only returned memos and get those without trip wage records
      final returnedMemos = <Map<String, dynamic>>[];
      for (final memo in memos) {
        // Check if tripStatus is 'returned' (this is in the memo data)
        final tripStatus = memo['tripStatus'] as String?;
        if (tripStatus == 'returned') {
          final dmId = memo['dmId'] as String?;
          if (dmId != null) {
            // Check if trip wage already exists
            final existingWage = await _repository.fetchTripWageByDmId(dmId);
            if (existingWage == null) {
              returnedMemos.add(memo);
            }
          }
        }
      }

      emit(state.copyWith(returnedDMs: returnedMemos));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading returned DMs: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load returned delivery memos: ${e.toString()}',
      ));
    }
  }

  /// Create trip wage
  Future<String> createTripWage(TripWage tripWage) async {
    try {
      final tripWageId = await _repository.createTripWage(tripWage);
      await loadTripWages();
      return tripWageId;
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error creating trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Update trip wage
  Future<void> updateTripWage(String tripWageId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateTripWage(tripWageId, updates);
      await loadTripWages();
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error updating trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Delete trip wage with wage and attendance revert
  /// Uses Cloud Function to atomically revert all changes
  Future<void> deleteTripWage(String tripWageId) async {
    try {
      // Get trip wage details before deletion to check if revert is needed
      final tripWage = await _repository.getTripWage(tripWageId);
      if (tripWage == null) {
        throw Exception('Trip wage not found');
      }

      // If trip wage was processed (has wage transactions), use Cloud Function to revert and delete atomically
      if (tripWage.status == TripWageStatus.processed &&
          tripWage.wageTransactionIds != null &&
          (tripWage.wageTransactionIds?.isNotEmpty ?? false)) {
        final wageService = _wageCalculationService;
        if (wageService != null) {
          // Cloud Function handles transaction deletion, attendance revert, and trip wage deletion atomically
          await wageService.revertTripWages(tripWage: tripWage);
          // Trip wage is already deleted by Cloud Function, just reload active DMs
          if (state.selectedDate != null) {
            await loadActiveDMsForDate(state.selectedDate!);
          }
          await loadTripWages();
          return;
        } else {
          throw Exception('Wage calculation service not available for revert');
        }
      }

      // If trip wage was not processed, just delete the trip wage document
      await _repository.deleteTripWage(tripWageId);
      if (state.selectedDate != null) {
        await loadActiveDMsForDate(state.selectedDate!);
      }
      await loadTripWages();
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error deleting trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Get trip wage by ID
  Future<TripWage?> getTripWage(String tripWageId) async {
    try {
      return await _repository.getTripWage(tripWageId);
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error getting trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to get trip wage: ${e.toString()}',
      ));
      return null;
    }
  }

  /// Get trip wage by DM ID
  Future<TripWage?> getTripWageByDmId(String dmId) async {
    try {
      return await _repository.fetchTripWageByDmId(dmId);
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error getting trip wage by DM ID: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Load active DMs for a specific date
  Future<void> loadActiveDMsForDate(DateTime date) async {
    try {
      emit(state.copyWith(status: ViewStatus.loading));
      
      // Set start and end of day for the selected date
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));
      
      final memos = await _deliveryMemoRepository
          .watchDeliveryMemos(
            organizationId: _organizationId,
            status: 'active',
            startDate: startOfDay,
            endDate: endOfDay,
          )
          .first;

      // Load all active DMs and check for existing trip wages
      final activeDMs = <Map<String, dynamic>>[];
      for (final memo in memos) {
        final dmId = memo['dmId'] as String?;
        if (dmId != null) {
          // Check if trip wage already exists and add full trip wage data to the memo
          final existingWage = await _repository.fetchTripWageByDmId(dmId);
          final memoWithWageInfo = Map<String, dynamic>.from(memo);
          if (existingWage != null) {
            memoWithWageInfo['hasTripWage'] = true;
            // fetchTripWageByDmId returns TripWage.fromJson(doc.data(), doc.id)
            // which sets tripWageId to doc.id if missing, so existingWage.tripWageId should be valid
            // But to be safe, ensure it's not empty
            if (existingWage.tripWageId.isEmpty) {
              // Skip this DM if tripWageId is invalid (shouldn't happen, but handle edge case)
              debugPrint('[TripWagesCubit] Warning: Trip wage found but tripWageId is empty for dmId: $dmId');
              continue;
            }
            memoWithWageInfo['tripWageId'] = existingWage.tripWageId;
            memoWithWageInfo['tripWageStatus'] = existingWage.status.name;
            memoWithWageInfo['tripWage'] = existingWage; // Include full trip wage object
            // Include wage breakdown for easy access
            memoWithWageInfo['totalWages'] = existingWage.totalWages;
            memoWithWageInfo['loadingWages'] = existingWage.loadingWages;
            memoWithWageInfo['unloadingWages'] = existingWage.unloadingWages;
            memoWithWageInfo['loadingWagePerEmployee'] = existingWage.loadingWagePerEmployee;
            memoWithWageInfo['unloadingWagePerEmployee'] = existingWage.unloadingWagePerEmployee;
            memoWithWageInfo['loadingEmployeeIds'] = existingWage.loadingEmployeeIds;
            memoWithWageInfo['unloadingEmployeeIds'] = existingWage.unloadingEmployeeIds;
          } else {
            memoWithWageInfo['hasTripWage'] = false;
          }
          activeDMs.add(memoWithWageInfo);
        }
      }

      emit(state.copyWith(
        status: ViewStatus.success,
        activeDMs: activeDMs,
        selectedDate: date,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading active DMs: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load active DMs: ${e.toString()}',
      ));
    }
  }

  /// Load employees filtered by role title
  Future<void> loadEmployeesByRole(String roleTitle) async {
      if (_employeesRepository == null) {
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Employees repository not available',
        ));
        return;
      }

      try {
        emit(state.copyWith(status: ViewStatus.loading));
        
        final allEmployees = await _employeesRepository.fetchEmployees(_organizationId);
      
      // Filter employees where any job role title matches (case-insensitive)
      final filteredEmployees = allEmployees.where((employee) {
        return employee.jobRoles.values.any(
          (jobRole) => jobRole.jobRoleTitle.toUpperCase() == roleTitle.toUpperCase(),
        );
      }).toList();

      emit(state.copyWith(
        status: ViewStatus.success,
        loadingEmployees: filteredEmployees,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading employees by role: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load employees: ${e.toString()}',
      ));
    }
  }

  /// Calculate wage for a quantity using LoadingUnloadingConfig
  double calculateWageForQuantity(int quantity, WageCalculationMethod method) {
    if (method.methodType != WageMethodType.loadingUnloading) {
      debugPrint('[TripWagesCubit] Method is not loading/unloading type');
      return 0.0;
    }

    final config = method.config as LoadingUnloadingConfig;

    // Use wagePerQuantity map to find matching range
    if (config.wagePerQuantity != null && config.wagePerQuantity!.isNotEmpty) {
      return _getWageForQuantity(quantity, config.wagePerQuantity!);
    }

    // Fallback to wagePerUnit if available
    if (config.wagePerUnit != null) {
      return quantity * config.wagePerUnit!;
    }

    return 0.0;
  }

  /// Get wage for a quantity using quantity ranges (same logic as WageCalculationService)
  double _getWageForQuantity(int quantity, Map<String, double> wagePerQuantity) {
    double? bestMatch;
    int? bestRangeMax;

    for (final entry in wagePerQuantity.entries) {
      final rangeStr = entry.key; // e.g., "0-1000" or "1001-2000"
      final wage = entry.value;

      final rangeParts = rangeStr.split('-');
      if (rangeParts.length == 2) {
        final min = int.tryParse(rangeParts[0]);
        final max = int.tryParse(rangeParts[1]);

        if (min != null && max != null) {
          if (quantity >= min && quantity <= max) {
            // Check if this is a better match (smaller range or higher max)
            if (bestRangeMax == null || max < bestRangeMax) {
              bestMatch = wage;
              bestRangeMax = max;
            }
          }
        }
      }
    }

    if (bestMatch != null) {
      return bestMatch;
    }

    // If no match found, use the highest range that quantity exceeds
    double? fallback;
    for (final entry in wagePerQuantity.entries) {
      final rangeStr = entry.key;
      final wage = entry.value;

      final rangeParts = rangeStr.split('-');
      if (rangeParts.length == 2) {
        final max = int.tryParse(rangeParts[1]);
        if (max != null && quantity > max) {
          fallback = wage; // Use the last range that quantity exceeds
        }
      }
    }

    return fallback ?? 0.0;
  }

  /// Load wage settings
  Future<void> loadWageSettings() async {
    if (_wageSettingsRepository == null) {
      return;
    }

    try {
      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      emit(state.copyWith(wageSettings: settings));
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error loading wage settings: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
    }
  }

  /// Create trip wage from DM with employee selections
  Future<String> createTripWageFromDM({
    required Map<String, dynamic> dm,
    required String methodId,
    required List<String> loadingEmployeeIds,
    required List<String> unloadingEmployeeIds,
    required String createdBy,
    bool sameEmployees = false,
  }) async {
    try {
      // Get quantity from DM
      final items = dm['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) {
        throw Exception('DM has no items');
      }
      final firstItem = items[0] as Map<String, dynamic>;
      final quantity = firstItem['fixedQuantityPerTrip'] as int? ?? 0;

      // Get wage settings and calculate wage
      WageCalculationMethod? method;
      double totalWage = 0.0;
      
      if (_wageSettingsRepository != null) {
        final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
        if (settings != null) {
          method = settings.calculationMethods[methodId];
          if (method != null) {
            totalWage = calculateWageForQuantity(quantity, method);
          }
        }
      }

      // Calculate wage distribution (always 50/50 split)
      final loadingWages = totalWage * 0.5;
      final unloadingWages = totalWage * 0.5;

      // Calculate per-employee wages
      final loadingWagePerEmployee = loadingEmployeeIds.isNotEmpty
          ? loadingWages / loadingEmployeeIds.length
          : 0.0;
      final unloadingWagePerEmployee = unloadingEmployeeIds.isNotEmpty
          ? unloadingWages / unloadingEmployeeIds.length
          : 0.0;

      // Create TripWage
      final tripWage = TripWage(
        tripWageId: '', // Will be generated by repository
        organizationId: _organizationId,
        dmId: dm['dmId'] as String? ?? '',
        tripId: dm['tripId'] as String? ?? '',
        orderId: dm['orderId'] as String?,
        productId: firstItem['productId'] as String?,
        productName: firstItem['productName'] as String?,
        quantityDelivered: quantity,
        methodId: methodId,
        loadingEmployeeIds: loadingEmployeeIds,
        unloadingEmployeeIds: unloadingEmployeeIds,
        totalWages: totalWage,
        loadingWages: loadingWages,
        unloadingWages: unloadingWages,
        loadingWagePerEmployee: loadingWagePerEmployee,
        unloadingWagePerEmployee: unloadingWagePerEmployee,
        status: TripWageStatus.recorded, // Start with recorded status
        createdBy: createdBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final tripWageId = await createTripWage(tripWage);
      return tripWageId;
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error creating trip wage from DM: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Calculate wages for a trip wage (update status to calculated)
  Future<void> calculateTripWage(String tripWageId) async {
    try {
      final tripWage = await getTripWage(tripWageId);
      if (tripWage == null) {
        throw Exception('Trip wage not found');
      }

      if (_wageSettingsRepository == null) {
        throw Exception('Wage settings repository not available');
      }

      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      if (settings == null) {
        throw Exception('Wage settings not found');
      }

      final method = settings.calculationMethods[tripWage.methodId];
      if (method == null) {
        throw Exception('Wage method not found');
      }

      // Recalculate wages
      final totalWage = calculateWageForQuantity(tripWage.quantityDelivered, method);
      final loadingWages = totalWage * 0.5;
      final unloadingWages = totalWage * 0.5;
      final loadingWagePerEmployee = tripWage.loadingEmployeeIds.isNotEmpty
          ? loadingWages / tripWage.loadingEmployeeIds.length
          : 0.0;
      final unloadingWagePerEmployee = tripWage.unloadingEmployeeIds.isNotEmpty
          ? unloadingWages / tripWage.unloadingEmployeeIds.length
          : 0.0;

      await updateTripWage(tripWageId, {
        'totalWages': totalWage,
        'loadingWages': loadingWages,
        'unloadingWages': unloadingWages,
        'loadingWagePerEmployee': loadingWagePerEmployee,
        'unloadingWagePerEmployee': unloadingWagePerEmployee,
        'status': TripWageStatus.calculated.name,
      });
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error calculating trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to calculate trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Process trip wage (call Cloud Function to create transactions and record attendance)
  Future<List<String>> processTripWage(String tripWageId, DateTime paymentDate) async {
    try {
      final tripWage = await getTripWage(tripWageId);
      if (tripWage == null) {
        throw Exception('Trip wage not found');
      }

      if (tripWage.loadingWages == null ||
          tripWage.unloadingWages == null ||
          tripWage.loadingWagePerEmployee == null ||
          tripWage.unloadingWagePerEmployee == null) {
        throw Exception('Trip wage must have calculated wages before processing');
      }

      if (_wageSettingsRepository == null || _wageCalculationService == null) {
        throw Exception('Wage calculation service not available');
      }

      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      if (settings == null) {
        throw Exception('Wage settings not found');
      }

      final method = settings.calculationMethods[tripWage.methodId];
      if (method == null) {
        throw Exception('Wage method not found');
      }

      // Get current user from FirebaseAuth
      final currentUser = FirebaseAuth.instance.currentUser;
      final createdBy = currentUser?.uid ?? 'system';

      final transactionIds = await _wageCalculationService.processTripWages(
        tripWage,
        method,
        createdBy,
        paymentDate,
      );

      return transactionIds;
    } catch (e, stackTrace) {
      debugPrint('[TripWagesCubit] Error processing trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to process trip wage: ${e.toString()}',
      ));
      rethrow;
    }
  }
}

