import 'package:cloud_functions/cloud_functions.dart';
import 'package:core_models/core_models.dart';
import 'package:core_datasources/employee_wages/employee_wages_data_source.dart';
import 'package:core_datasources/production_batches/production_batches_data_source.dart';
import 'package:core_datasources/trip_wages/trip_wages_data_source.dart';
import 'package:core_datasources/employee_attendance/employee_attendance_data_source.dart';

class WageCalculationService {
  WageCalculationService({
    required EmployeeWagesDataSource employeeWagesDataSource,
    required ProductionBatchesDataSource productionBatchesDataSource,
    required TripWagesDataSource tripWagesDataSource,
    EmployeeAttendanceDataSource? employeeAttendanceDataSource,
    FirebaseFunctions? functions,
  })  : _employeeWagesDataSource = employeeWagesDataSource,
        _productionBatchesDataSource = productionBatchesDataSource,
        _tripWagesDataSource = tripWagesDataSource,
        _employeeAttendanceDataSource = employeeAttendanceDataSource,
        _functions = functions ?? _initializeFunctions();

  static FirebaseFunctions _initializeFunctions() {
    // Must match functions region (asia-south1) in functions/src/shared/function-config.ts
    return FirebaseFunctions.instanceFor(region: 'asia-south1');
  }

  final EmployeeWagesDataSource _employeeWagesDataSource;
  final ProductionBatchesDataSource _productionBatchesDataSource;
  final TripWagesDataSource _tripWagesDataSource;
  final EmployeeAttendanceDataSource? _employeeAttendanceDataSource;
  final FirebaseFunctions _functions;

  /// Calculate wages for a production batch
  /// Returns calculated totalWages and wagePerEmployee
  Map<String, double> calculateProductionWages(
    ProductionBatch batch,
    WageCalculationMethod method,
  ) {
    if (method.methodType != WageMethodType.production) {
      throw ArgumentError('Method must be of type production');
    }

    final config = method.config as ProductionWageConfig;

    // Get product-specific pricing if available
    double productionPricePerUnit = config.productionPricePerUnit;
    double stackingPricePerUnit = config.stackingPricePerUnit;

    if (batch.productId != null &&
        config.productSpecificPricing != null &&
        config.productSpecificPricing!.containsKey(batch.productId)) {
      final productPricing = config.productSpecificPricing![batch.productId]!;
      productionPricePerUnit = productPricing.productionPricePerUnit;
      stackingPricePerUnit = productPricing.stackingPricePerUnit;
    }

    // Calculate total wages: (Y × productionPrice) + (Z × stackingPrice)
    final totalWages = (batch.totalBricksProduced * productionPricePerUnit) +
        (batch.totalBricksStacked * stackingPricePerUnit);

    // Calculate wage per employee: totalWages / X (number of employees)
    final employeeCount = batch.employeeIds.length;
    if (employeeCount == 0) {
      throw ArgumentError('Batch must have at least one employee');
    }

    final wagePerEmployee = totalWages / employeeCount;

    return {
      'totalWages': totalWages,
      'wagePerEmployee': wagePerEmployee,
    };
  }

  /// Calculate wages for a trip wage (loading/unloading)
  /// Returns calculated wages breakdown
  Map<String, double> calculateTripWages(
    TripWage tripWage,
    WageCalculationMethod method,
  ) {
    if (method.methodType != WageMethodType.loadingUnloading) {
      throw ArgumentError('Method must be of type loadingUnloading');
    }

    final config = method.config as LoadingUnloadingConfig;

    // Calculate total wages based on quantity delivered
    double totalWages = 0.0;

    if (config.wagePerUnit != null) {
      // Use fixed rate per unit
      totalWages = tripWage.quantityDelivered * config.wagePerUnit!;
    } else if (config.wagePerQuantity != null &&
        config.wagePerQuantity!.isNotEmpty) {
      // Use quantity-based wage tiers
      totalWages = _getWageForQuantity(
          tripWage.quantityDelivered, config.wagePerQuantity!);
    } else {
      throw ArgumentError(
          'Loading/unloading config must have wagePerUnit or wagePerQuantity');
    }

    // Split wages: loadingPercentage and unloadingPercentage
    final loadingWages = totalWages * (config.loadingPercentage / 100);
    final unloadingWages = totalWages * (config.unloadingPercentage / 100);

    // Calculate per-employee wages
    final loadingEmployeeCount = tripWage.loadingEmployeeIds.length;
    final unloadingEmployeeCount = tripWage.unloadingEmployeeIds.length;

    final loadingWagePerEmployee = loadingEmployeeCount > 0
        ? loadingWages / loadingEmployeeCount
        : 0.0;
    final unloadingWagePerEmployee = unloadingEmployeeCount > 0
        ? unloadingWages / unloadingEmployeeCount
        : 0.0;

    return {
      'totalWages': totalWages,
      'loadingWages': loadingWages,
      'unloadingWages': unloadingWages,
      'loadingWagePerEmployee': loadingWagePerEmployee,
      'unloadingWagePerEmployee': unloadingWagePerEmployee,
    };
  }

  /// Get wage for a quantity using quantity ranges
  double _getWageForQuantity(int quantity, Map<String, double> wagePerQuantity) {
    double? bestMatch = null;
    int? bestRangeMax = null;

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
    double? fallback = null;
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

  /// Process production batch wages - creates transactions for all employees atomically via Cloud Function
  Future<List<String>> processProductionBatchWages(
    ProductionBatch batch,
    WageCalculationMethod method,
    String createdBy,
    DateTime paymentDate,
  ) async {
    if (batch.totalWages == null || batch.wagePerEmployee == null) {
      throw ArgumentError('Batch must have calculated wages before processing');
    }

    // Call Cloud Function to process wages atomically
    final callable = _functions.httpsCallable('processProductionBatchWages');

    try {
      // Convert paymentDate to Timestamp for Cloud Function
      final paymentDateTimestamp = {
        '_seconds': paymentDate.millisecondsSinceEpoch ~/ 1000,
        '_nanoseconds': (paymentDate.millisecondsSinceEpoch % 1000) * 1000000,
      };

      final result = await callable.call({
        'batchId': batch.batchId,
        'paymentDate': paymentDateTimestamp,
        'createdBy': createdBy,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final transactionIds = (data['transactionIds'] as List<dynamic>?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        return transactionIds;
      } else {
        throw Exception('Cloud Function returned unsuccessful result: $data');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to process production batch wages via Cloud Function: $e');
    }
  }

  /// Process trip wages - creates transactions and records attendance atomically via Cloud Function
  Future<List<String>> processTripWages(
    TripWage tripWage,
    WageCalculationMethod method,
    String createdBy,
    DateTime paymentDate,
  ) async {
    if (tripWage.loadingWages == null ||
        tripWage.unloadingWages == null ||
        tripWage.loadingWagePerEmployee == null ||
        tripWage.unloadingWagePerEmployee == null) {
      throw ArgumentError('Trip wage must have calculated wages before processing');
    }

    // Call Cloud Function to process wages atomically
    final callable = _functions.httpsCallable('processTripWages');

    try {
      // Validate tripWageId is not empty
      if (tripWage.tripWageId.isEmpty) {
        throw Exception('Trip wage ID cannot be empty');
      }

      // Convert paymentDate to ISO string for Cloud Function (more reliable than timestamp format)
      final paymentDateIsoString = paymentDate.toIso8601String();

      final result = await callable.call({
        'tripWageId': tripWage.tripWageId,
        'paymentDate': paymentDateIsoString,
        'createdBy': createdBy,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] == true) {
        final transactionIds = (data['transactionIds'] as List<dynamic>?)
                ?.map((id) => id.toString())
                .toList() ??
            [];
        return transactionIds;
      } else {
        throw Exception('Cloud Function returned unsuccessful result: $data');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to process trip wages via Cloud Function: $e');
    }
  }

  /// Revert trip wages - deletes transactions and reverts attendance atomically via Cloud Function
  Future<void> revertTripWages({
    required TripWage tripWage,
  }) async {
    // Only revert if trip wage was processed (has transactions)
    if (tripWage.status != TripWageStatus.processed ||
        tripWage.wageTransactionIds == null ||
        tripWage.wageTransactionIds!.isEmpty) {
      // No transactions to revert, just return
      return;
    }

    // Call Cloud Function to revert wages and attendance atomically
    final callable = _functions.httpsCallable('revertTripWages');

    try {
      final result = await callable.call({
        'tripWageId': tripWage.tripWageId,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Cloud Function returned unsuccessful result: $data');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to revert trip wages via Cloud Function: $e');
    }
  }

  /// Revert production batch wages - deletes transactions and reverts attendance atomically via Cloud Function
  Future<void> revertProductionBatchWages({
    required ProductionBatch batch,
  }) async {
    // Only revert if batch was processed (has transactions)
    if (batch.status != ProductionBatchStatus.processed ||
        batch.wageTransactionIds == null ||
        batch.wageTransactionIds!.isEmpty) {
      // No transactions to revert, just return
      return;
    }

    // Call Cloud Function to revert wages and attendance atomically
    final callable = _functions.httpsCallable('revertProductionBatchWages');

    try {
      final result = await callable.call({
        'batchId': batch.batchId,
      });

      final data = result.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception('Cloud Function returned unsuccessful result: $data');
      }
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to revert production batch wages via Cloud Function: $e');
    }
  }

  /// Recalculate and update wages - deletes old transactions and creates new ones
  Future<void> recalculateAndUpdateWages({
    required String sourceId,
    required String sourceType,
    required String organizationId,
    required WageCalculationMethod method,
    required String createdBy,
    required DateTime paymentDate,
  }) async {
    // This method would need to:
    // 1. Find all transactions with matching sourceId and sourceType
    // 2. Delete those transactions (which will trigger Cloud Functions to update ledgers)
    // 3. Recalculate wages based on current batch/trip wage data
    // 4. Create new transactions

    // Note: Transaction deletion should be handled carefully to maintain data integrity
    // This is a simplified version - in production, you'd want to use a transaction
    // or Cloud Function to ensure atomicity

    throw UnimplementedError(
        'recalculateAndUpdateWages - implementation depends on transaction deletion logic');
  }
}

