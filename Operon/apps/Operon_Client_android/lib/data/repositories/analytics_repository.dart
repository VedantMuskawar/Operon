import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/data/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

class AnalyticsRepository {
  AnalyticsRepository({AnalyticsService? service})
      : _service = service ?? AnalyticsService();

  final AnalyticsService _service;

  Future<ClientsAnalytics?> fetchClientsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) async {
    final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    // Document ID format: clients_{organizationId}_{financialYear}
    final docId = organizationId != null && organizationId.isNotEmpty
        ? 'clients_${organizationId}_$fyLabel'
        : 'clients_$fyLabel';
    debugPrint('[AnalyticsRepository] Fetching $docId');
    final payload = await _service.fetchAnalyticsDocument(docId);
    if (payload == null) {
      debugPrint('[AnalyticsRepository] No payload for $docId');
      return null;
    }
    debugPrint('[AnalyticsRepository] Received analytics payload for $docId with keys: ${payload.keys}');
    return ClientsAnalytics.fromMap(payload);
  }

  String _financialYearForDate(DateTime date) {
    final fyStartYear = date.month >= 4 ? date.year : date.year - 1;
    final first = (fyStartYear % 100).toString().padLeft(2, '0');
    final second = ((fyStartYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY$first$second';
  }
}

class ClientsAnalytics {
  ClientsAnalytics({
    required this.activeClientsMonthly,
    required this.onboardingMonthly,
    required this.generatedAt,
  });

  factory ClientsAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    Map<String, double> extractSeries(String key) {
      // Try nested structure first: metrics[key][values]
      var values = map['metrics']?[key]?['values'];
      
      // If not found, try flat dot-notation keys (Firestore style)
      // Keys like: metrics.userOnboarding.values.2025-12
      if (values == null || (values is Map && values.isEmpty)) {
        final prefix = 'metrics.$key.values.';
        final flatData = <String, double>{};
        map.forEach((mapKey, mapValue) {
          if (mapKey.startsWith(prefix)) {
            final monthKey = mapKey.substring(prefix.length);
            if (mapValue is num) {
              flatData[monthKey] = mapValue.toDouble();
            }
          }
        });
        if (flatData.isNotEmpty) {
          debugPrint('[ClientsAnalytics] Extracted $key from flat keys: ${flatData.keys.toList()}');
          return flatData;
        }
      }
      
      if (values is Map<String, dynamic>) {
        final result = values.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
        debugPrint('[ClientsAnalytics] Extracted $key from nested structure: ${result.keys.toList()}');
        return result;
      }
      
      debugPrint('[ClientsAnalytics] No values found for $key. Available keys: ${map.keys.where((k) => k.contains(key)).take(10).toList()}');
      return {};
    }

    return ClientsAnalytics(
      activeClientsMonthly: extractSeries('activeClients'),
      onboardingMonthly: extractSeries('userOnboarding'),
      generatedAt: generatedAt,
    );
  }

  final Map<String, double> activeClientsMonthly;
  final Map<String, double> onboardingMonthly;
  final DateTime? generatedAt;
}

