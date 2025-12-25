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
  }) async {
    final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    final docId = 'clients_$fyLabel';
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
      final values = map['metrics']?[key]?['values'];
      if (values is Map<String, dynamic>) {
        return values.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      }
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

