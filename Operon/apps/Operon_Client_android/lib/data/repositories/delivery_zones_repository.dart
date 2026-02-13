import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';

class DeliveryZonesRepository {
  DeliveryZonesRepository({required DeliveryZonesDataSource dataSource})
      : _dataSource = dataSource;

  final DeliveryZonesDataSource _dataSource;

  Future<List<DeliveryZone>> fetchZones(String orgId) {
    return _dataSource.fetchZones(orgId);
  }

  Future<List<DeliveryCity>> fetchCities(String orgId) {
    return _dataSource.fetchCities(orgId);
  }

  Future<List<DeliveryZonePrice>> fetchZonePrices(
    String orgId,
    String zoneId,
  ) {
    return _dataSource.fetchZonePrices(orgId, zoneId);
  }

  Future<String> createZone(String orgId, DeliveryZone zone) {
    return _dataSource.createZone(orgId, zone);
  }

  Future<void> updateZone(String orgId, DeliveryZone zone) {
    return _dataSource.updateZone(orgId, zone);
  }

  Future<void> deleteZone(String orgId, String zoneId) {
    return _dataSource.deleteZone(orgId, zoneId);
  }

  Future<void> upsertPrice({
    required String orgId,
    required String zoneId,
    required DeliveryZonePrice price,
  }) {
    return _dataSource.upsertPrice(
      orgId: orgId,
      zoneId: zoneId,
      price: price,
    );
  }

  Future<void> deletePrice({
    required String orgId,
    required String zoneId,
    required String productId,
  }) {
    return _dataSource.deletePrice(
      orgId: orgId,
      zoneId: zoneId,
      productId: productId,
    );
  }

  Future<String> createCity({
    required String orgId,
    required String cityName,
  }) {
    return _dataSource.createCity(
      orgId: orgId,
      cityName: cityName,
    );
  }

  Future<void> renameCity({
    required String orgId,
    required String cityId,
    required String oldName,
    required String newName,
  }) {
    return _dataSource.renameCity(
      orgId: orgId,
      cityId: cityId,
      oldName: oldName,
      newName: newName,
    );
  }

  Future<void> deleteCity({
    required String orgId,
    required String cityId,
    required String cityName,
  }) {
    return _dataSource.deleteCity(
      orgId: orgId,
      cityId: cityId,
      cityName: cityName,
    );
  }
}

