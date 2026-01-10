import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'production_batches_state.dart';

class ProductionBatchesCubit extends Cubit<ProductionBatchesState> {
  ProductionBatchesCubit({
    required ProductionBatchesRepository repository,
    required String organizationId,
    WageSettingsRepository? wageSettingsRepository,
    WageCalculationService? wageCalculationService,
  })  : _repository = repository,
        _organizationId = organizationId,
        _wageSettingsRepository = wageSettingsRepository,
        _wageCalculationService = wageCalculationService,
        super(const ProductionBatchesState());

  final ProductionBatchesRepository _repository;
  final String _organizationId;
  final WageSettingsRepository? _wageSettingsRepository;
  final WageCalculationService? _wageCalculationService;
  StreamSubscription<List<ProductionBatch>>? _batchesSubscription;

  @override
  Future<void> close() {
    _batchesSubscription?.cancel();
    return super.close();
  }

  /// Load production batches
  Future<void> loadBatches({
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final batches = await _repository.fetchProductionBatches(
        _organizationId,
        status: status,
        startDate: startDate,
        endDate: endDate,
        methodId: methodId,
        limit: limit,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        batches: batches,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error loading batches: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load production batches: ${e.toString()}',
      ));
    }
  }

  /// Watch batches stream for real-time updates
  void watchBatches({
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) {
    _batchesSubscription?.cancel();
    _batchesSubscription = _repository
        .watchProductionBatches(
      _organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      limit: limit,
    )
        .listen(
      (batches) {
        emit(state.copyWith(
          status: ViewStatus.success,
          batches: batches,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint('[ProductionBatchesCubit] Error in batches stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load production batches: ${error.toString()}',
        ));
      },
    );
  }

  /// Create production batch
  Future<String> createBatch(ProductionBatch batch) async {
    try {
      final batchId = await _repository.createProductionBatch(batch);
      
      if (batchId.isEmpty) {
        throw Exception('Created batch has empty ID');
      }
      
      await loadBatches();
      return batchId;
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error creating batch: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create production batch: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Update production batch
  Future<void> updateBatch(String batchId, Map<String, dynamic> updates) async {
    try {
      await _repository.updateProductionBatch(batchId, updates);
      await loadBatches();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error updating batch: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update production batch: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Delete production batch
  Future<void> deleteBatch(String batchId) async {
    try {
      await _repository.deleteProductionBatch(batchId);
      await loadBatches();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error deleting batch: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete production batch: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Get production batch by ID
  Future<ProductionBatch?> getBatch(String batchId) async {
    try {
      return await _repository.getProductionBatch(batchId);
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error getting batch: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to get production batch: ${e.toString()}',
      ));
      return null;
    }
  }

  /// Set filter status
  void setStatusFilter(ProductionBatchStatus? status) {
    emit(state.copyWith(selectedStatus: status));
  }

  /// Set date range filter
  void setDateRange(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate: start, endDate: end));
  }

  /// Set search query
  void setSearchQuery(String? query) {
    emit(state.copyWith(searchQuery: query));
  }

  /// Set selected batch for detail view
  void setSelectedBatch(ProductionBatch? batch) {
    emit(state.copyWith(selectedBatch: batch));
  }

  /// Calculate wages for a production batch
  Future<void> calculateWages(String batchId) async {
    try {
      if (batchId.isEmpty) {
        throw Exception('Batch ID cannot be empty');
      }
      
      final batch = await _repository.getProductionBatch(batchId);
      if (batch == null) {
        throw Exception('Batch not found');
      }

      if (_wageSettingsRepository == null || _wageCalculationService == null) {
        throw Exception('Wage calculation service not available');
      }

      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      if (settings == null || !settings.enabled) {
        throw Exception('Wage settings not enabled');
      }

      final method = settings.calculationMethods[batch.methodId];
      if (method == null || !method.enabled) {
        throw Exception('Wage method not found or disabled');
      }

      if (method.methodType != WageMethodType.production) {
        throw Exception('Method must be of type production');
      }

      final calculations = _wageCalculationService.calculateProductionWages(batch, method);

      await _repository.updateProductionBatch(batchId, {
        'totalWages': calculations['totalWages'],
        'wagePerEmployee': calculations['wagePerEmployee'],
        'status': ProductionBatchStatus.calculated.name,
      });

      await loadBatches();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error calculating wages: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to calculate wages: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Approve a production batch
  Future<void> approveBatch(String batchId) async {
    try {
      await _repository.updateProductionBatch(batchId, {
        'status': ProductionBatchStatus.approved.name,
      });
      await loadBatches();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error approving batch: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to approve batch: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Process wages for a production batch (create transactions)
  Future<List<String>> processWages(String batchId, DateTime paymentDate) async {
    try {
      final batch = await _repository.getProductionBatch(batchId);
      if (batch == null) {
        throw Exception('Batch not found');
      }

      if (batch.totalWages == null || batch.wagePerEmployee == null) {
        throw Exception('Batch must have calculated wages before processing');
      }

      if (_wageSettingsRepository == null || _wageCalculationService == null) {
        throw Exception('Wage calculation service not available');
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final settings = await _wageSettingsRepository.fetchWageSettings(_organizationId);
      if (settings == null) {
        throw Exception('Wage settings not found');
      }

      final method = settings.calculationMethods[batch.methodId];
      if (method == null) {
        throw Exception('Wage method not found');
      }

      final transactionIds = await _wageCalculationService.processProductionBatchWages(
        batch,
        method,
        currentUser.uid,
        paymentDate,
      );

      await loadBatches();
      return transactionIds;
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchesCubit] Error processing wages: $e');
      debugPrint('[ProductionBatchesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to process wages: ${e.toString()}',
      ));
      rethrow;
    }
  }
}

