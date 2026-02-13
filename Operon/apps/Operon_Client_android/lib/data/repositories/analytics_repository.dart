import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/data/services/analytics_service.dart';
import 'package:flutter/foundation.dart';

class AnalyticsRepository {
  AnalyticsRepository({AnalyticsService? service})
      : _service = service ?? AnalyticsService();

  final AnalyticsService _service;

  /// Get list of year-month strings (YYYY-MM) for a date range
  List<String> _getMonthsInRange(DateTime startDate, DateTime endDate) {
    final months = <String>[];
    var current = DateTime(startDate.year, startDate.month, 1);
    final end = DateTime(endDate.year, endDate.month, 1);
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      final year = current.year;
      final month = current.month.toString().padLeft(2, '0');
      months.add('$year-$month');
      // Move to next month
      if (current.month == 12) {
        current = DateTime(current.year + 1, 1, 1);
      } else {
        current = DateTime(current.year, current.month + 1, 1);
      }
    }
    
    return months;
  }

  /// Helper to calculate date range from financial year or use provided dates
  (DateTime, DateTime) _calculateDateRange({
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? asOf,
  }) {
    if (startDate != null && endDate != null) {
      return (startDate, endDate);
    }
    if (financialYear != null) {
      final match = RegExp(r'FY(\d{2})(\d{2})').firstMatch(financialYear);
      if (match != null) {
        final startYear = 2000 + int.parse(match.group(1)!);
        return (DateTime(startYear, 4, 1), DateTime(startYear + 1, 3, 31, 23, 59, 59));
      }
    }
    // Default to current FY
    final now = asOf ?? DateTime.now();
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    return (DateTime(fyStartYear, 4, 1), DateTime(fyStartYear + 1, 3, 31, 23, 59, 59));
  }

  Future<ClientsAnalytics?> fetchClientsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (organizationId == null || organizationId.isEmpty) {
      return null;
    }

    final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      asOf: asOf,
    );

    final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
    if (months.isEmpty) return null;

    final docIds = months.map((month) => 'clients_${organizationId}_$month').toList();
    final docs = await _service.fetchAnalyticsDocuments(docIds);
    if (docs.isEmpty) {
      debugPrint('[AnalyticsRepository] No clients analytics documents found');
      return null;
    }

    // Aggregate: sum totalActiveClients (use max since it's org-wide), sum onboarding
    var totalActiveClients = 0;
    final onboardingMonthly = <String, double>{};
    
    for (final doc in docs) {
      final activeClients = (doc['metrics']?['totalActiveClients'] as num?)?.toInt() ?? 0;
      if (activeClients > totalActiveClients) {
        totalActiveClients = activeClients; // Use max since it's org-wide
      }
      final onboarding = (doc['metrics']?['userOnboarding'] as num?)?.toDouble() ?? 0.0;
      final month = doc['month'] as String?;
      if (month != null && onboarding > 0) {
        onboardingMonthly[month] = (onboardingMonthly[month] ?? 0.0) + onboarding;
      }
    }

    final aggregatedPayload = {
      'metrics': {
        'totalActiveClients': totalActiveClients,
        'userOnboarding': {
          'values': onboardingMonthly,
        },
      },
      'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
    };

    debugPrint('[AnalyticsRepository] Received aggregated clients analytics with ${onboardingMonthly.length} months');
    return ClientsAnalytics.fromMap(aggregatedPayload);
  }

  Future<EmployeesAnalytics?> fetchEmployeesAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (organizationId == null || organizationId.isEmpty) {
      return null;
    }

    final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      asOf: asOf,
    );

    final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
    if (months.isEmpty) return null;

    final docIds = months.map((month) => 'employees_${organizationId}_$month').toList();
    final docs = await _service.fetchAnalyticsDocuments(docIds);
    if (docs.isEmpty) {
      debugPrint('[AnalyticsRepository] No employees analytics documents found');
      return null;
    }

    // Aggregate: use max totalActiveEmployees (org-wide), sum wagesCreditMonthly
    var totalActiveEmployees = 0;
    final wagesCreditMonthly = <String, double>{};
    for (final doc in docs) {
      final active = (doc['metrics']?['totalActiveEmployees'] as num?)?.toInt() ?? 0;
      if (active > totalActiveEmployees) totalActiveEmployees = active;
      final wages = (doc['metrics']?['wagesCreditMonthly'] as num?)?.toDouble() ?? 0.0;
      final month = doc['month'] as String?;
      if (month != null && wages > 0) {
        wagesCreditMonthly[month] = (wagesCreditMonthly[month] ?? 0.0) + wages;
      }
    }
    final aggregatedPayload = {
      'metrics': {
        'totalActiveEmployees': totalActiveEmployees,
        'wagesCreditMonthly': {'values': wagesCreditMonthly},
      },
      'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
    };
    return EmployeesAnalytics.fromMap(aggregatedPayload);
  }

  Future<VendorsAnalytics?> fetchVendorsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (organizationId == null || organizationId.isEmpty) {
      return null;
    }

    final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
      financialYear: financialYear,
      startDate: startDate,
      endDate: endDate,
      asOf: asOf,
    );

    final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
    if (months.isEmpty) return null;

    final docIds = months.map((month) => 'vendors_${organizationId}_$month').toList();
    final docs = await _service.fetchAnalyticsDocuments(docIds);
    if (docs.isEmpty) {
      debugPrint('[AnalyticsRepository] No vendors analytics documents found');
      return null;
    }

    // Aggregate: use max totalPayable (org-wide), merge purchasesByVendorType
    var totalPayable = 0.0;
    final purchasesByVendorType = <String, Map<String, double>>{};
    for (final doc in docs) {
      final payable = (doc['metrics']?['totalPayable'] as num?)?.toDouble() ?? 0.0;
      if (payable > totalPayable) totalPayable = payable;
      final purchases = doc['metrics']?['purchasesByVendorType'] as Map<String, dynamic>?;
      if (purchases != null) {
        purchases.forEach((vendorType, amount) {
          if (amount is num) {
            purchasesByVendorType.putIfAbsent(vendorType, () => <String, double>{});
            final month = doc['month'] as String?;
            if (month != null) {
              purchasesByVendorType[vendorType]![month] = 
                (purchasesByVendorType[vendorType]![month] ?? 0.0) + amount.toDouble();
            }
          }
        });
      }
    }
    final aggregatedPayload = {
      'metrics': {
        'totalPayable': totalPayable,
        'purchasesByVendorType': {'values': purchasesByVendorType},
      },
      'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
    };
    return VendorsAnalytics.fromMap(aggregatedPayload);
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

