import 'package:core_models/core_models.dart';
import 'package:core_datasources/employee_wages/employee_wages_data_source.dart';
import 'package:core_datasources/production_batches/production_batches_data_source.dart';
import 'package:core_datasources/trip_wages/trip_wages_data_source.dart';

class WageCalculationService {
  WageCalculationService({
    required EmployeeWagesDataSource employeeWagesDataSource,
    required ProductionBatchesDataSource productionBatchesDataSource,
    required TripWagesDataSource tripWagesDataSource,
  })  : _employeeWagesDataSource = employeeWagesDataSource,
        _productionBatchesDataSource = productionBatchesDataSource,
        _tripWagesDataSource = tripWagesDataSource;

  final EmployeeWagesDataSource _employeeWagesDataSource;
  final ProductionBatchesDataSource _productionBatchesDataSource;
  final TripWagesDataSource _tripWagesDataSource;

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

  /// Process production batch wages - creates transactions for all employees
  Future<List<String>> processProductionBatchWages(
    ProductionBatch batch,
    WageCalculationMethod method,
    String createdBy,
    DateTime paymentDate,
  ) async {
    if (batch.totalWages == null || batch.wagePerEmployee == null) {
      throw ArgumentError('Batch must have calculated wages before processing');
    }

    final transactionIds = <String>[];

    // Create a transaction for each employee
    for (final employeeId in batch.employeeIds) {
      final transactionId = await _employeeWagesDataSource
          .createWageCreditTransaction(
        organizationId: batch.organizationId,
        employeeId: employeeId,
        amount: batch.wagePerEmployee!,
        paymentDate: paymentDate,
        createdBy: createdBy,
        description: 'Production Batch #${batch.batchId}',
        metadata: {
          'sourceType': 'productionBatch',
          'sourceId': batch.batchId,
          'methodId': method.methodId,
          'batchId': batch.batchId,
        },
      );
      transactionIds.add(transactionId);
    }

    // Update batch with transaction IDs and status
    await _productionBatchesDataSource.updateProductionBatch(
      batch.batchId,
      {
        'wageTransactionIds': transactionIds,
        'status': ProductionBatchStatus.processed.name,
      },
    );

    return transactionIds;
  }

  /// Process trip wages - creates transactions for loading and unloading employees
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

    final transactionIds = <String>[];

    // Create transactions for loading employees
    for (final employeeId in tripWage.loadingEmployeeIds) {
      final transactionId = await _employeeWagesDataSource
          .createWageCreditTransaction(
        organizationId: tripWage.organizationId,
        employeeId: employeeId,
        amount: tripWage.loadingWagePerEmployee!,
        paymentDate: paymentDate,
        createdBy: createdBy,
        description: 'Trip Wage - Loading (DM: ${tripWage.dmId})',
        metadata: {
          'sourceType': 'tripWage',
          'sourceId': tripWage.tripWageId,
          'methodId': method.methodId,
          'tripId': tripWage.tripId,
          'dmId': tripWage.dmId,
          'taskType': 'loading',
        },
      );
      transactionIds.add(transactionId);
    }

    // Create transactions for unloading employees
    for (final employeeId in tripWage.unloadingEmployeeIds) {
      final transactionId = await _employeeWagesDataSource
          .createWageCreditTransaction(
        organizationId: tripWage.organizationId,
        employeeId: employeeId,
        amount: tripWage.unloadingWagePerEmployee!,
        paymentDate: paymentDate,
        createdBy: createdBy,
        description: 'Trip Wage - Unloading (DM: ${tripWage.dmId})',
        metadata: {
          'sourceType': 'tripWage',
          'sourceId': tripWage.tripWageId,
          'methodId': method.methodId,
          'tripId': tripWage.tripId,
          'dmId': tripWage.dmId,
          'taskType': 'unloading',
        },
      );
      transactionIds.add(transactionId);
    }

    // Update trip wage with transaction IDs and status
    await _tripWagesDataSource.updateTripWage(
      tripWage.tripWageId,
      {
        'wageTransactionIds': transactionIds,
        'status': TripWageStatus.processed.name,
      },
    );

    return transactionIds;
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

