import 'package:core_models/core_models.dart';
import 'package:core_datasources/production_batches/production_batches_data_source.dart';

class ProductionBatchesRepository {
  ProductionBatchesRepository({
    required ProductionBatchesDataSource dataSource,
  }) : _dataSource = dataSource;

  final ProductionBatchesDataSource _dataSource;

  Future<String> createProductionBatch(ProductionBatch batch) {
    return _dataSource.createProductionBatch(batch);
  }

  Future<List<ProductionBatch>> fetchProductionBatches(
    String organizationId, {
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) {
    return _dataSource.fetchProductionBatches(
      organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      limit: limit,
    );
  }

  Stream<List<ProductionBatch>> watchProductionBatches(
    String organizationId, {
    ProductionBatchStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? methodId,
    int? limit,
  }) {
    return _dataSource.watchProductionBatches(
      organizationId,
      status: status,
      startDate: startDate,
      endDate: endDate,
      methodId: methodId,
      limit: limit,
    );
  }

  Future<ProductionBatch?> getProductionBatch(String batchId) {
    return _dataSource.getProductionBatch(batchId);
  }

  Future<void> updateProductionBatch(
    String batchId,
    Map<String, dynamic> updates,
  ) {
    return _dataSource.updateProductionBatch(batchId, updates);
  }

  Future<void> deleteProductionBatch(String batchId) {
    return _dataSource.deleteProductionBatch(batchId);
  }
}

