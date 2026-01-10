import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'production_batch_templates_state.dart';

class ProductionBatchTemplatesCubit
    extends Cubit<ProductionBatchTemplatesState> {
  ProductionBatchTemplatesCubit({
    required ProductionBatchTemplatesRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const ProductionBatchTemplatesState());

  final ProductionBatchTemplatesRepository _repository;
  final String _organizationId;
  StreamSubscription<List<ProductionBatchTemplate>>? _templatesSubscription;

  @override
  Future<void> close() {
    _templatesSubscription?.cancel();
    return super.close();
  }

  /// Load production batch templates
  Future<void> loadTemplates() async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final templates = await _repository.fetchBatchTemplates(_organizationId);
      emit(state.copyWith(
        status: ViewStatus.success,
        templates: templates,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchTemplatesCubit] Error loading templates: $e');
      debugPrint('[ProductionBatchTemplatesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load production batch templates: ${e.toString()}',
      ));
    }
  }

  /// Watch templates stream for real-time updates
  void watchTemplates() {
    _templatesSubscription?.cancel();
    _templatesSubscription = _repository
        .watchBatchTemplates(_organizationId)
        .listen(
      (templates) {
        emit(state.copyWith(
          status: ViewStatus.success,
          templates: templates,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint(
            '[ProductionBatchTemplatesCubit] Error in templates stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message:
              'Failed to load production batch templates: ${error.toString()}',
        ));
      },
    );
  }

  /// Create production batch template
  Future<String> createTemplate(ProductionBatchTemplate template) async {
    try {
      final batchId = await _repository.createBatchTemplate(template);
      await loadTemplates();
      return batchId;
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchTemplatesCubit] Error creating template: $e');
      debugPrint('[ProductionBatchTemplatesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message:
            'Failed to create production batch template: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Update production batch template
  Future<void> updateTemplate(
    String batchId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await _repository.updateBatchTemplate(_organizationId, batchId, updates);
      await loadTemplates();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchTemplatesCubit] Error updating template: $e');
      debugPrint('[ProductionBatchTemplatesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message:
            'Failed to update production batch template: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Delete production batch template
  Future<void> deleteTemplate(String batchId) async {
    try {
      await _repository.deleteBatchTemplate(_organizationId, batchId);
      await loadTemplates();
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchTemplatesCubit] Error deleting template: $e');
      debugPrint('[ProductionBatchTemplatesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message:
            'Failed to delete production batch template: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Get production batch template by ID
  Future<ProductionBatchTemplate?> getTemplate(String batchId) async {
    try {
      return await _repository.getBatchTemplate(_organizationId, batchId);
    } catch (e, stackTrace) {
      debugPrint('[ProductionBatchTemplatesCubit] Error getting template: $e');
      debugPrint('[ProductionBatchTemplatesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message:
            'Failed to get production batch template: ${e.toString()}',
      ));
      return null;
    }
  }
}

