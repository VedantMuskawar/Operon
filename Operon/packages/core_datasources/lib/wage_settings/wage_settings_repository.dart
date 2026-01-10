import 'package:core_models/core_models.dart';
import 'package:core_datasources/wage_settings/wage_settings_data_source.dart';

class WageSettingsRepository {
  WageSettingsRepository({required WageSettingsDataSource dataSource})
      : _dataSource = dataSource;

  final WageSettingsDataSource _dataSource;

  Future<WageSettings?> fetchWageSettings(String organizationId) {
    return _dataSource.fetchWageSettings(organizationId);
  }

  Future<void> updateWageSettings(String organizationId, WageSettings settings) {
    return _dataSource.updateWageSettings(organizationId, settings);
  }

  Stream<WageSettings?> watchWageSettings(String organizationId) {
    return _dataSource.watchWageSettings(organizationId);
  }
}

