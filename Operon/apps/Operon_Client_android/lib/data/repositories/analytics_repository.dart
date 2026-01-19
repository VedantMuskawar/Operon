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

  Future<EmployeesAnalytics?> fetchEmployeesAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) async {
    final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    // Document ID format: employees_{organizationId}_{financialYear}
    final docId = organizationId != null && organizationId.isNotEmpty
        ? 'employees_${organizationId}_$fyLabel'
        : 'employees_$fyLabel';
    debugPrint('[AnalyticsRepository] Fetching $docId');
    final payload = await _service.fetchAnalyticsDocument(docId);
    if (payload == null) {
      debugPrint('[AnalyticsRepository] No payload for $docId');
      return null;
    }
    debugPrint('[AnalyticsRepository] Received analytics payload for $docId with keys: ${payload.keys}');
    return EmployeesAnalytics.fromMap(payload);
  }

  Future<VendorsAnalytics?> fetchVendorsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) async {
    final fyLabel = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    // Document ID format: vendors_{organizationId}_{financialYear}
    final docId = organizationId != null && organizationId.isNotEmpty
        ? 'vendors_${organizationId}_$fyLabel'
        : 'vendors_$fyLabel';
    debugPrint('[AnalyticsRepository] Fetching $docId');
    final payload = await _service.fetchAnalyticsDocument(docId);
    if (payload == null) {
      debugPrint('[AnalyticsRepository] No payload for $docId');
      return null;
    }
    debugPrint('[AnalyticsRepository] Received analytics payload for $docId with keys: ${payload.keys}');
    return VendorsAnalytics.fromMap(payload);
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
    required this.totalActiveClients,
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

    // Extract totalActiveClients (single number, not monthly)
    final totalActiveClients = map['metrics']?['totalActiveClients'] as num?;
    final totalActiveClientsValue = totalActiveClients?.toInt() ?? 0;

    return ClientsAnalytics(
      totalActiveClients: totalActiveClientsValue,
      onboardingMonthly: extractSeries('userOnboarding'),
      generatedAt: generatedAt,
    );
  }

  final int totalActiveClients;
  final Map<String, double> onboardingMonthly;
  final DateTime? generatedAt;
}

class EmployeesAnalytics {
  EmployeesAnalytics({
    required this.totalActiveEmployees,
    required this.wagesCreditMonthly,
    required this.generatedAt,
  });

  factory EmployeesAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    Map<String, double> extractSeries(String key) {
      // Try nested structure first: metrics[key][values]
      var values = map['metrics']?[key]?['values'];
      
      // If not found, try flat dot-notation keys (Firestore style)
      // Keys like: metrics.wagesCreditMonthly.values.2025-12
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
          debugPrint('[EmployeesAnalytics] Extracted $key from flat keys: ${flatData.keys.toList()}');
          return flatData;
        }
      }
      
      if (values is Map<String, dynamic>) {
        final result = values.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
        debugPrint('[EmployeesAnalytics] Extracted $key from nested structure: ${result.keys.toList()}');
        return result;
      }
      
      debugPrint('[EmployeesAnalytics] No values found for $key. Available keys: ${map.keys.where((k) => k.contains(key)).take(10).toList()}');
      return {};
    }

    // Extract totalActiveEmployees (single number, not monthly)
    final totalActiveEmployees = map['metrics']?['totalActiveEmployees'] as num?;
    final totalActiveEmployeesValue = totalActiveEmployees?.toInt() ?? 0;

    return EmployeesAnalytics(
      totalActiveEmployees: totalActiveEmployeesValue,
      wagesCreditMonthly: extractSeries('wagesCreditMonthly'),
      generatedAt: generatedAt,
    );
  }

  final int totalActiveEmployees;
  final Map<String, double> wagesCreditMonthly;
  final DateTime? generatedAt;
}

class VendorsAnalytics {
  VendorsAnalytics({
    required this.totalPayable,
    required this.purchasesByVendorType,
    required this.generatedAt,
  });

  factory VendorsAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    // Extract totalPayable (single number, not monthly)
    final totalPayable = map['metrics']?['totalPayable'] as num?;
    final totalPayableValue = totalPayable?.toDouble() ?? 0.0;

    // Extract purchasesByVendorType
    // Structure: metrics.purchasesByVendorType.values.{vendorType}.{monthKey}
    Map<String, Map<String, double>> extractPurchasesByVendorType() {
      // Try nested structure first: metrics.purchasesByVendorType.values
      var values = map['metrics']?['purchasesByVendorType']?['values'];
      
      // If not found, try flat dot-notation keys (Firestore style)
      // Keys like: metrics.purchasesByVendorType.values.rawMaterial.2024-04
      if (values == null || (values is Map && values.isEmpty)) {
        const prefix = 'metrics.purchasesByVendorType.values.';
        final nestedData = <String, Map<String, double>>{};
        
        map.forEach((mapKey, mapValue) {
          if (mapKey.startsWith(prefix)) {
            // Extract vendorType and monthKey from key like: metrics.purchasesByVendorType.values.rawMaterial.2024-04
            final afterPrefix = mapKey.substring(prefix.length);
            final parts = afterPrefix.split('.');
            
            if (parts.length == 2) {
              final vendorType = parts[0];
              final monthKey = parts[1];
              
              if (mapValue is num) {
                if (!nestedData.containsKey(vendorType)) {
                  nestedData[vendorType] = {};
                }
                nestedData[vendorType]![monthKey] = mapValue.toDouble();
              }
            }
          }
        });
        
        if (nestedData.isNotEmpty) {
          debugPrint('[VendorsAnalytics] Extracted purchasesByVendorType from flat keys: ${nestedData.keys.toList()}');
          return nestedData;
        }
      }
      
      // Try nested structure
      if (values is Map<String, dynamic>) {
        final result = <String, Map<String, double>>{};
        
        values.forEach((vendorType, monthlyData) {
          if (monthlyData is Map<String, dynamic>) {
            result[vendorType] = monthlyData.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            );
          }
        });
        
        debugPrint('[VendorsAnalytics] Extracted purchasesByVendorType from nested structure: ${result.keys.toList()}');
        return result;
      }
      
      debugPrint('[VendorsAnalytics] No purchasesByVendorType found. Available keys: ${map.keys.where((k) => k.contains('purchasesByVendorType')).take(10).toList()}');
      return {};
    }

    return VendorsAnalytics(
      totalPayable: totalPayableValue,
      purchasesByVendorType: extractPurchasesByVendorType(),
      generatedAt: generatedAt,
    );
  }

  final double totalPayable;
  final Map<String, Map<String, double>> purchasesByVendorType; // {vendorType: {month: amount}}
  final DateTime? generatedAt;
}

