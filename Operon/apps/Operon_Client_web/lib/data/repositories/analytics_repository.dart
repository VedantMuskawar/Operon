import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/data/datasources/analytics_data_source.dart';
import 'package:flutter/foundation.dart';

class AnalyticsRepository {
  AnalyticsRepository({required AnalyticsDataSource dataSource})
      : _dataSource = dataSource;

  final AnalyticsDataSource _dataSource;

  String _financialYearForDate(DateTime date) {
    final fyStartYear = date.month >= 4 ? date.year : date.year - 1;
    final first = (fyStartYear % 100).toString().padLeft(2, '0');
    final second = ((fyStartYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY$first$second';
  }

  Future<ClientsAnalytics?> fetchClientsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) async {
    try {
      final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
      // Document ID format: clients_{organizationId}_{financialYear}
      final docId = organizationId != null && organizationId.isNotEmpty
          ? 'clients_${organizationId}_$fyLabel'
          : 'clients_$fyLabel';
      
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Fetching $docId');
      }
      
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) {
        if (kDebugMode) {
          debugPrint('[AnalyticsRepository] No payload for $docId');
        }
        return null;
      }
      
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Received analytics payload for $docId');
      }
      
      return ClientsAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Error fetching analytics: $e');
      }
      return null;
    }
  }

  Stream<ClientsAnalytics?> watchClientsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) {
    final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    final docId = organizationId != null && organizationId.isNotEmpty
        ? 'clients_${organizationId}_$fyLabel'
        : 'clients_$fyLabel';
    
    return _dataSource.watchAnalyticsDocument(docId).map((payload) {
      if (payload == null) return null;
      return ClientsAnalytics.fromMap(payload);
    });
  }
}

class ClientsAnalytics {
  ClientsAnalytics({
    required this.totalActiveClients,
    required this.onboardingMonthly,
    this.generatedAt,
    this.totalOrders,
    this.corporateCount,
    this.individualCount,
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
          return flatData;
        }
      }
      
      if (values is Map<String, dynamic>) {
        return values.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      }
      
      return {};
    }

    // Extract totalActiveClients (single number, not monthly)
    final totalActiveClients = map['metrics']?['totalActiveClients'] as num?;
    final totalActiveClientsValue = totalActiveClients?.toInt() ?? 0;

    // Extract total orders if available
    final totalOrders = map['metrics']?['totalOrders'] as num?;
    final corporateCount = map['metrics']?['corporateCount'] as num?;
    final individualCount = map['metrics']?['individualCount'] as num?;

    return ClientsAnalytics(
      totalActiveClients: totalActiveClientsValue,
      onboardingMonthly: extractSeries('userOnboarding'),
      generatedAt: generatedAt,
      totalOrders: totalOrders?.toInt(),
      corporateCount: corporateCount?.toInt(),
      individualCount: individualCount?.toInt(),
    );
  }

  final int totalActiveClients;
  final Map<String, double> onboardingMonthly;
  final DateTime? generatedAt;
  final int? totalOrders;
  final int? corporateCount;
  final int? individualCount;
}





