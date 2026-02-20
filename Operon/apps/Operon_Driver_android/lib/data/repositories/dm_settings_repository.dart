import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';

class DmSettingsRepository {
  DmSettingsRepository({required DmSettingsDataSource dataSource})
      : _dataSource = dataSource;

  final DmSettingsDataSource _dataSource;

  Future<DmSettings?> fetchDmSettings(String orgId) {
    return _dataSource.fetchDmSettings(orgId);
  }

  Future<void> updateDmSettings(String orgId, DmSettings settings) {
    return _dataSource.updateDmSettings(orgId, settings);
  }

  Stream<DmSettings?> watchDmSettings(String orgId) {
    return _dataSource.watchDmSettings(orgId);
  }
}
