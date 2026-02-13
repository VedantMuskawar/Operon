import 'package:core_models/core_models.dart';
import 'package:core_datasources/wage_settings/wage_settings_data_source.dart';

class WageSettingsRepository {
  WageSettingsRepository({required WageSettingsDataSource dataSource})
      : _dataSource = dataSource;

  final WageSettingsDataSource _dataSource;

  final Map<String, ({DateTime timestamp, WageSettings? data})> _cache = {};
  final Map<String, Future<WageSettings?>> _inFlight = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<WageSettings?> fetchWageSettings(
    String organizationId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache[organizationId];
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return Future.value(cached.data);
      }

      final inFlight = _inFlight[organizationId];
      if (inFlight != null) return inFlight;
    }

    final future = _dataSource.fetchWageSettings(organizationId);
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

  Future<void> updateWageSettings(String organizationId, WageSettings settings) {
    _cache[organizationId] = (timestamp: DateTime.now(), data: settings);
    return _dataSource.updateWageSettings(organizationId, settings);
  }

  Stream<WageSettings?> watchWageSettings(String organizationId) {
    return _dataSource.watchWageSettings(organizationId);
  }
}

