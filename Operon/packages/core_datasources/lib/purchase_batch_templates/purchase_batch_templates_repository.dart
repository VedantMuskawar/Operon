import 'package:core_models/core_models.dart';
import 'package:core_datasources/purchase_batch_templates/purchase_batch_templates_data_source.dart';

class PurchaseBatchTemplatesRepository {
  PurchaseBatchTemplatesRepository({
    required PurchaseBatchTemplatesDataSource dataSource,
  }) : _dataSource = dataSource;

  final PurchaseBatchTemplatesDataSource _dataSource;

  Future<String> createTemplate(PurchaseBatchTemplate template) {
    return _dataSource.createTemplate(template);
  }

  Future<List<PurchaseBatchTemplate>> fetchTemplates(
    String organizationId,
  ) {
    return _dataSource.fetchTemplates(organizationId);
  }

  Stream<List<PurchaseBatchTemplate>> watchTemplates(
    String organizationId,
  ) {
    return _dataSource.watchTemplates(organizationId);
  }

  Future<PurchaseBatchTemplate?> getTemplate(
    String organizationId,
    String templateId,
  ) {
    return _dataSource.getTemplate(organizationId, templateId);
  }

  Future<void> updateTemplate(
    String organizationId,
    String templateId,
    Map<String, dynamic> updates,
  ) {
    return _dataSource.updateTemplate(organizationId, templateId, updates);
  }

  Future<void> deleteTemplate(
    String organizationId,
    String templateId,
  ) {
    return _dataSource.deleteTemplate(organizationId, templateId);
  }
}
