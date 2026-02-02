import 'package:dash_web/data/datasources/bonus_settings_data_source.dart';

class BonusSettingsRepository {
  BonusSettingsRepository({required BonusSettingsDataSource dataSource})
      : _dataSource = dataSource;

  final BonusSettingsDataSource _dataSource;

  Future<BonusSettings?> fetch(String organizationId) {
    return _dataSource.fetch(organizationId);
  }

  Future<void> save({
    required String organizationId,
    required BonusSettings settings,
    String? updatedBy,
  }) {
    return _dataSource.save(
      organizationId: organizationId,
      settings: settings,
      updatedBy: updatedBy,
    );
  }
}
