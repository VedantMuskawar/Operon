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
      super(ProductionBatchesState());

  final ProductionBatchesRepository _repository;
  final String _organizationId;
  final WageSettingsRepository? _wageSettingsRepository;
  final WageCalculationService? _wageCalculationService;
  StreamSubscription<List<ProductionBatch>>? _batchesSubscription;
  Timer? _searchDebounce;

  @override
  Future<void> close() {
    _batchesSubscription?.cancel();
    _searchDebounce?.cancel();
    return super.close();
  }

  void _emitBatches(List<ProductionBatch> batches) {
    emit(state.copyWith(
      status: ViewStatus.success,
      batches: batches,
      message: null,
    ));
  }

  void _upsertBatch(ProductionBatch batch) {
    final updated = List<ProductionBatch>.from(state.batches);
    final index = updated.indexWhere((b) => b.batchId == batch.batchId);
    if (index == -1) {
      updated.add(batch);
    } else {
      updated[index] = batch;
    }
    updated.sort((a, b) => b.batchDate.compareTo(a.batchDate));
    _emitBatches(updated);
  }

  void _removeBatch(String batchId) {
    final updated = state.batches.where((b) => b.batchId != batchId).toList();
    _emitBatches(updated);
  }

  ProductionBatch _applyUpdatesToBatch(
    ProductionBatch batch,
    Map<String, dynamic> updates,
  ) {
    ProductionBatchStatus status = batch.status;
    if (updates['status'] != null) {
      final statusValue = updates['status'];
      if (statusValue is ProductionBatchStatus) {
        status = statusValue;
      } else if (statusValue is String) {
        status = ProductionBatchStatus.values.firstWhere(
          (s) => s.name == statusValue,
          orElse: () => batch.status,
        );
      }
    }

    final batchDate = updates.containsKey('batchDate')
        ? updates['batchDate'] as DateTime?
        : batch.batchDate;
    final methodId = updates.containsKey('methodId')
        ? updates['methodId'] as String?
        : batch.methodId;
    final productId = updates.containsKey('productId')
        ? updates['productId'] as String?
        : batch.productId;
    final productName = updates.containsKey('productName')
        ? updates['productName'] as String?
        : batch.productName;
    final totalBricksProduced = updates.containsKey('totalBricksProduced')
        ? (updates['totalBricksProduced'] as num?)?.toInt() ?? 0
        : batch.totalBricksProduced;
    final totalBricksStacked = updates.containsKey('totalBricksStacked')
        ? (updates['totalBricksStacked'] as num?)?.toInt() ?? 0
        : batch.totalBricksStacked;
    final employeeIds = updates.containsKey('employeeIds')
        ? (updates['employeeIds'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            []
        : batch.employeeIds;
    final employeeNames = updates.containsKey('employeeNames')
        ? (updates['employeeNames'] as List?)
            ?.map((e) => e.toString())
            .toList()
        : batch.employeeNames;
    final totalWages = updates.containsKey('totalWages')
        ? (updates['totalWages'] as num?)?.toDouble()
        : batch.totalWages;
    final wagePerEmployee = updates.containsKey('wagePerEmployee')
        ? (updates['wagePerEmployee'] as num?)?.toDouble()
        : batch.wagePerEmployee;
    final wageTransactionIds = updates.containsKey('wageTransactionIds')
        ? (updates['wageTransactionIds'] as List?)
            ?.map((e) => e.toString())
            .toList()
        : batch.wageTransactionIds;
    final notes = updates.containsKey('notes')
        ? updates['notes'] as String?
        : batch.notes;

    return ProductionBatch(
      batchId: batch.batchId,
      organizationId: batch.organizationId,
      batchDate: batchDate ?? batch.batchDate,
      methodId: methodId ?? batch.methodId,
      productId: productId,
      productName: productName,
      totalBricksProduced: totalBricksProduced,
      totalBricksStacked: totalBricksStacked,
      employeeIds: employeeIds,
      employeeNames: employeeNames,
      totalWages: totalWages,
      wagePerEmployee: wagePerEmployee,
      status: status,
      wageTransactionIds: wageTransactionIds,
      createdBy: batch.createdBy,
      createdAt: batch.createdAt,
      updatedAt: DateTime.now(),
      notes: notes,
      metadata: batch.metadata,
    );
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
      _emitBatches(batches);
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
      
      final now = DateTime.now();
      final createdBatch = batch.copyWith(
        batchId: batchId,
        createdAt: now,
        updatedAt: now,
      );
      _upsertBatch(createdBatch);
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
      final existing = state.batches.firstWhere(
        (b) => b.batchId == batchId,
        orElse: () => ProductionBatch(
          batchId: batchId,
          organizationId: _organizationId,
          batchDate: DateTime.now(),
          methodId: updates['methodId'] as String? ?? '',
          totalBricksProduced:
              (updates['totalBricksProduced'] as num?)?.toInt() ?? 0,
          totalBricksStacked:
              (updates['totalBricksStacked'] as num?)?.toInt() ?? 0,
          employeeIds: const [],
          status: ProductionBatchStatus.recorded,
          createdBy: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _upsertBatch(_applyUpdatesToBatch(existing, updates));
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

  /// Delete production batch with wage and attendance revert
  /// Uses Cloud Function to atomically revert all changes
  Future<void> deleteBatch(String batchId) async {
    try {
      // Get batch details before deletion to check if revert is needed
      final batch = await _repository.getProductionBatch(batchId);
      if (batch == null) {
        throw Exception('Batch not found');
      }

      // If batch was processed (has wage transactions), use Cloud Function to revert and delete atomically
      if (batch.status == ProductionBatchStatus.processed &&
          batch.wageTransactionIds != null &&
          batch.wageTransactionIds!.isNotEmpty) {
        final wageService = _wageCalculationService;
        if (wageService != null) {
          // Cloud Function handles transaction deletion, attendance revert, and batch deletion atomically
          await wageService.revertProductionBatchWages(batch: batch);
          // Batch is already deleted by Cloud Function, just reload
          _removeBatch(batchId);
          return;
        } else {
          throw Exception('Wage calculation service not available for revert');
        }
      }

      // If batch was not processed, just delete the batch document
      await _repository.deleteProductionBatch(batchId);
      _removeBatch(batchId);
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

  /// Set filter status (kept for backward compatibility)
  void setStatusFilter(ProductionBatchStatus? status) {
    emit(state.copyWith(selectedStatus: status));
  }

  /// Set workflow tab
  void setSelectedTab(WorkflowTab tab) {
    emit(state.copyWith(selectedTab: tab));
  }

  /// Set date range filter
  void setDateRange(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate: start, endDate: end));
  }

  /// Set second date range filter
  void setDateRange2(DateTime? start, DateTime? end) {
    emit(state.copyWith(startDate2: start, endDate2: end));
  }

  /// Clear date range filter
  void clearDateRange() {
    emit(state.copyWith(startDate: null, endDate: null));
  }

  /// Clear second date range filter
  void clearDateRange2() {
    emit(state.copyWith(startDate2: null, endDate2: null));
  }

  /// Clear all filters
  void clearAllFilters() {
    emit(state.copyWith(
      selectedTab: WorkflowTab.all,
      startDate: null,
      endDate: null,
      startDate2: null,
      endDate2: null,
      searchQuery: null,
      selectedStatus: null,
    ));
  }

  /// Set search query
  void setSearchQuery(String? query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (state.searchQuery != query) {
        emit(state.copyWith(searchQuery: query));
      }
    });
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
      _upsertBatch(
        batch.copyWith(
          totalWages: calculations['totalWages'],
          wagePerEmployee: calculations['wagePerEmployee'],
          status: ProductionBatchStatus.calculated,
          updatedAt: DateTime.now(),
        ),
      );
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
      final existing = state.batches.firstWhere(
        (b) => b.batchId == batchId,
        orElse: () => ProductionBatch(
          batchId: batchId,
          organizationId: _organizationId,
          batchDate: DateTime.now(),
          methodId: '',
          totalBricksProduced: 0,
          totalBricksStacked: 0,
          employeeIds: const [],
          status: ProductionBatchStatus.recorded,
          createdBy: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _upsertBatch(
        existing.copyWith(
          status: ProductionBatchStatus.approved,
          updatedAt: DateTime.now(),
        ),
      );
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
      _upsertBatch(
        batch.copyWith(
          status: ProductionBatchStatus.processed,
          wageTransactionIds: transactionIds,
          updatedAt: DateTime.now(),
        ),
      );
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

