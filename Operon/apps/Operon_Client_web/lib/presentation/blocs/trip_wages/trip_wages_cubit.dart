import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/data/repositories/job_roles_repository.dart';
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
    JobRolesRepository? jobRolesRepository,
    WageSettingsRepository? wageSettingsRepository,
    WageCalculationService? wageCalculationService,
  })  : _repository = repository,
        _deliveryMemoRepository = deliveryMemoRepository,
        _organizationId = organizationId,
        _employeesRepository = employeesRepository,
      _jobRolesRepository = jobRolesRepository,
        _wageSettingsRepository = wageSettingsRepository,
        _wageCalculationService = wageCalculationService,
        super(const TripWagesState());

  final TripWagesRepository _repository;
  final DeliveryMemoRepository _deliveryMemoRepository;
  final String _organizationId;
  final EmployeesRepository? _employeesRepository;
  final JobRolesRepository? _jobRolesRepository;
  final WageSettingsRepository? _wageSettingsRepository;
  final WageCalculationService? _wageCalculationService;
  StreamSubscription<List<TripWage>>? _tripWagesSubscription;

  final Map<String, String> _cachedJobRoleIdByTitle = {};
  String? _cachedRoleTitle;
  Future<void>? _loadingEmployeesFuture;

  @override
  Future<void> close() {
    _tripWagesSubscription?.cancel();
    return super.close();
  }

  Future<WageSettings?> _ensureWageSettings() async {
    if (state.wageSettings != null) return state.wageSettings;
    if (_wageSettingsRepository == null) return null;
    final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
    if (settings != null) {
      emit(state.copyWith(wageSettings: settings));
    }
    return settings;
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('[TripWagesCubit] User not authenticated. Cannot create trip wage.');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'User not authenticated. Please sign in again.',
      ));
      throw Exception('User not authenticated');
    }
    try {
      final tripWageId = await _repository.createTripWage(tripWage);
      if (state.tripWages.isNotEmpty) {
        await loadTripWages();
      }
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
      if (state.tripWages.isNotEmpty) {
        await loadTripWages();
      }
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
      emit(state.copyWith(status: ViewStatus.loading));
      
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
          if (state.tripWages.isNotEmpty) {
            await loadTripWages();
          }
          emit(state.copyWith(status: ViewStatus.success, message: 'Trip wage deleted successfully'));
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
      if (state.tripWages.isNotEmpty) {
        await loadTripWages();
      }
      emit(state.copyWith(status: ViewStatus.success, message: 'Trip wage deleted successfully'));
    } catch (e, stackTrace) {
      final errorMessage = _getErrorMessage(e);
      debugPrint('[TripWagesCubit] Error deleting trip wage: $e');
      debugPrint('[TripWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: errorMessage,
      ));
      rethrow;
    }
  }

  /// Helper method to extract user-friendly error messages
  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString();
    
    // First, check for specific error code patterns from Cloud Functions
    if (errorStr.contains('not-found')) {
      return 'Trip wage not found. It may have already been deleted.';
    } else if (errorStr.contains('invalid-argument')) {
      return 'Invalid trip wage data. Please check the details.';
    } else if (errorStr.contains('failed-precondition')) {
      return 'Cannot delete: Trip wage has already been processed. Please revert it first.';
    } else if (errorStr.contains('permission-denied')) {
      return 'You do not have permission to delete this trip wage.';
    } else if (errorStr.contains('unauthenticated')) {
      return 'Authentication expired. Please log in again.';
    } else if (errorStr.contains('internal')) {
      // Internal errors might have more details - extract them if available
      if (errorStr.contains('permission')) {
        return 'Permission error: You cannot delete this trip wage at this time.';
      } else if (errorStr.contains('not-found')) {
        return 'Trip wage not found. It may have already been deleted.';
      }
      return 'An internal server error occurred. Please try again later, or contact support if the problem persists.';
    } else if (errorStr.contains('Trip wage not found')) {
      return 'Trip wage not found. It may have already been deleted.';
    } else if (errorStr.contains('Wage calculation service not available')) {
      return 'Unable to process reversal. Please try again.';
    } else if (errorStr.contains('timeout') || errorStr.contains('deadline')) {
      return 'Request timed out. Please try again.';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    } else {
      debugPrint('[TripWagesCubit] Unmapped error: $errorStr');
      return 'Failed to delete trip wage: $errorStr';
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
      final endOfDay = startOfDay;
      
      final memos = await _deliveryMemoRepository
          .watchDeliveryMemos(
            organizationId: _organizationId,
            startDate: startOfDay,
            endDate: endOfDay,
          )
          .first;

      // Extract all DM IDs for batch fetching (PERFORMANCE CRITICAL)
      final dmIds = memos
          .map((memo) => memo['dmId'] as String?)
          .whereType<String>()
          .toList();

      // CRITICAL OPTIMIZATION: Batch fetch trip wages instead of N+1 queries
      // 50 DMs: 51 queries → 6 queries (1 DM fetch + 5 batches of 10)
      final tripWagesByDmId = dmIds.isNotEmpty
          ? await _repository.fetchTripWagesByDmIds(_organizationId, dmIds)
          : <String, TripWage>{};

      // Build active DMs with trip wage info (simplified structure)
      final activeDMs = <Map<String, dynamic>>[];
      for (final memo in memos) {
        final dmId = memo['dmId'] as String?;
        if (dmId == null) continue;

        final tripWage = tripWagesByDmId[dmId];
        
        // Simplified data structure: only essential fields
        final memoData = <String, dynamic>{
          ...memo,  // Keep original DM data
          'hasTripWage': tripWage != null,
          if (tripWage != null) ...{
            'tripWageId': tripWage.tripWageId,
            'tripWageStatus': tripWage.status.name,
            'tripWage': tripWage, // Full object for wage calculations
          },
        };
        activeDMs.add(memoData);
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

    final normalizedTitle = roleTitle.trim().toLowerCase();
    if (normalizedTitle.isEmpty) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Role title cannot be empty',
      ));
      return;
    }

    if (state.loadingEmployees.isNotEmpty &&
        _cachedRoleTitle != null &&
        _cachedRoleTitle == normalizedTitle) {
      return;
    }

    final inFlight = _loadingEmployeesFuture;
    if (inFlight != null) {
      return inFlight;
    }

    _loadingEmployeesFuture = _loadEmployeesByRoleInternal(normalizedTitle);
    try {
      await _loadingEmployeesFuture;
    } finally {
      _loadingEmployeesFuture = null;
    }
  }

  Future<void> _loadEmployeesByRoleInternal(String normalizedTitle) async {
    try {
      emit(state.copyWith(status: ViewStatus.loading));

      final employeesRepository = _employeesRepository;
      if (employeesRepository == null) {
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Employees repository not available',
        ));
        return;
      }

      String? jobRoleId = _cachedJobRoleIdByTitle[normalizedTitle];
      if (jobRoleId == null && _jobRolesRepository != null) {
        final roles = await _jobRolesRepository.fetchJobRoles(_organizationId);
        for (final role in roles) {
          if (role.title.trim().toLowerCase() == normalizedTitle) {
            jobRoleId = role.id;
            _cachedJobRoleIdByTitle[normalizedTitle] = role.id;
            break;
          }
        }
      }

      List<OrganizationEmployee> filteredEmployees;
      if (jobRoleId != null && jobRoleId.isNotEmpty) {
        filteredEmployees =
            await employeesRepository.fetchEmployeesByJobRole(_organizationId, jobRoleId);
      } else {
        final allEmployees = await employeesRepository.fetchEmployees(_organizationId);
        filteredEmployees = allEmployees.where((employee) {
          return employee.jobRoles.values.any(
            (jobRole) => jobRole.jobRoleTitle.trim().toLowerCase() == normalizedTitle,
          );
        }).toList();
      }

      _cachedRoleTitle = normalizedTitle;

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
      if (state.wageSettings != null) return;
      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      if (settings != null) {
        emit(state.copyWith(wageSettings: settings));
      }
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
      final currentUser = FirebaseAuth.instance.currentUser;
      final resolvedCreatedBy = createdBy.isNotEmpty
          ? createdBy
          : (currentUser?.uid ?? '');
      if (resolvedCreatedBy.isEmpty) {
        throw Exception('User not authenticated');
      }

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
      
      final settings = await _ensureWageSettings();
      if (settings != null) {
        method = settings.calculationMethods[methodId];
        if (method != null) {
          totalWage = calculateWageForQuantity(quantity, method);
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
        createdBy: resolvedCreatedBy,
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

      final settings = await _ensureWageSettings();
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

      final settings = await _ensureWageSettings();
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

