import 'package:dash_web/data/datasources/bonus_settings_data_source.dart';

class BonusSettingsRepository {
  BonusSettingsRepository({required BonusSettingsDataSource dataSource})
      : _dataSource = dataSource;

  final BonusSettingsDataSource _dataSource;

  final Map<String, ({DateTime timestamp, BonusSettings? data})> _cache = {};
  final Map<String, Future<BonusSettings?>> _inFlight = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<BonusSettings?> fetch(
    String organizationId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache[organizationId];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return Future.value(cached.data);
      }

      final inFlight = _inFlight[organizationId];
      if (inFlight != null) return inFlight;
    }

    final future = _dataSource.fetch(organizationId);
    _inFlight[organizationId] = future;
    return future.then((settings) {
      _cache[organizationId] = (timestamp: DateTime.now(), data: settings);
      _inFlight.remove(organizationId);
      return settings;
    }).catchError((e) {
      _inFlight.remove(organizationId);
      throw e;
    });
  }

  Future<void> save({
    required String organizationId,
    required BonusSettings settings,
    String? updatedBy,
  }) {
    _cache.remove(organizationId);
    return _dataSource.save(
      organizationId: organizationId,
      settings: settings,
      updatedBy: updatedBy,
    );
  }
}
