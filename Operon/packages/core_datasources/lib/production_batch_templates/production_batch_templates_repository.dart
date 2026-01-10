import 'package:core_models/core_models.dart';
import 'package:core_datasources/production_batch_templates/production_batch_templates_data_source.dart';

class ProductionBatchTemplatesRepository {
  ProductionBatchTemplatesRepository({
    required ProductionBatchTemplatesDataSource dataSource,
  }) : _dataSource = dataSource;

  final ProductionBatchTemplatesDataSource _dataSource;

  Future<String> createBatchTemplate(ProductionBatchTemplate template) {
    return _dataSource.createBatchTemplate(template);
  }

  Future<List<ProductionBatchTemplate>> fetchBatchTemplates(
    String organizationId,
  ) {
    return _dataSource.fetchBatchTemplates(organizationId);
  }

  Stream<List<ProductionBatchTemplate>> watchBatchTemplates(
    String organizationId,
  ) {
    return _dataSource.watchBatchTemplates(organizationId);
  }

  Future<ProductionBatchTemplate?> getBatchTemplate(
    String organizationId,
    String batchId,
  ) {
    return _dataSource.getBatchTemplate(organizationId, batchId);
  }

  Future<void> updateBatchTemplate(
    String organizationId,
    String batchId,
    Map<String, dynamic> updates,
  ) {
    return _dataSource.updateBatchTemplate(organizationId, batchId, updates);
  }

  Future<void> deleteBatchTemplate(
    String organizationId,
    String batchId,
  ) {
    return _dataSource.deleteBatchTemplate(organizationId, batchId);
  }
}

