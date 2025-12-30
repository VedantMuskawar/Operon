import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';

class RawMaterialsRepository {
  RawMaterialsRepository({required RawMaterialsDataSource dataSource})
      : _dataSource = dataSource;

  final RawMaterialsDataSource _dataSource;

  Future<List<RawMaterial>> fetchRawMaterials(String orgId) {
    return _dataSource.fetchRawMaterials(orgId);
  }

  Future<void> createRawMaterial(String orgId, RawMaterial material) {
    return _dataSource.createRawMaterial(orgId, material);
  }

  Future<void> updateRawMaterial(String orgId, RawMaterial material) {
    return _dataSource.updateRawMaterial(orgId, material);
  }

  Future<void> deleteRawMaterial(String orgId, String materialId) {
    return _dataSource.deleteRawMaterial(orgId, materialId);
  }

  Future<void> addStockHistoryEntry(
    String orgId,
    String materialId,
    StockHistoryEntry entry,
  ) {
    return _dataSource.addStockHistoryEntry(orgId, materialId, entry);
  }

  Future<List<StockHistoryEntry>> fetchStockHistory(
    String orgId,
    String materialId, {
    int? limit,
  }) {
    return _dataSource.fetchStockHistory(orgId, materialId, limit: limit);
  }

  Future<void> updateMaterialStock(
    String orgId,
    String materialId,
    int newStock,
  ) {
    return _dataSource.updateMaterialStock(orgId, materialId, newStock);
  }
}

