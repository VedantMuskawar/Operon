import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';
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

  /// Converts display format "FY 2025-2026" to doc ID format "FY2526".
  String _normalizeFyForDocId(String fy) {
    final trimmed = fy.trim();
    if (RegExp(r'^FY\d{4}$').hasMatch(trimmed)) return trimmed;
    final match = RegExp(r'FY\s*(\d{4})-(\d{4})').firstMatch(trimmed);
    if (match != null) {
      final start = match.group(1)!;
      final end = match.group(2)!;
      return 'FY${start.substring(2)}${end.substring(2)}';
    }
    return trimmed;
  }

  Future<ClientsAnalytics?> fetchClientsAnalytics({
    DateTime? asOf,
    String? financialYear,
    String? organizationId,
  }) async {
    try {
      final fyRaw = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
      final fyLabel = fyRaw.contains('-') ? _normalizeFyForDocId(fyRaw) : fyRaw;
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
    final fyRaw = financialYear ?? _financialYearForDate(asOf ?? DateTime.now());
    final fyLabel = fyRaw.contains('-') ? _normalizeFyForDocId(fyRaw) : fyRaw;
    final docId = organizationId != null && organizationId.isNotEmpty
        ? 'clients_${organizationId}_$fyLabel'
        : 'clients_$fyLabel';
    
    return _dataSource.watchAnalyticsDocument(docId).map((payload) {
      if (payload == null) return null;
      return ClientsAnalytics.fromMap(payload);
    });
  }

  /// Fetches transaction analytics for the given org and financial year.
  /// Document ID: transactions_{orgId}_{fy} (e.g. transactions_abc123_FY2526).
  /// Accepts FY in display form "FY 2025-2026" or compact "FY2526".
  Future<TransactionAnalytics?> fetchTransactionAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'transactions_${orgId}_$fyLabel';
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
        debugPrint('[AnalyticsRepository] Received transaction analytics for $docId');
      }
      return TransactionAnalytics.fromJson(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Error fetching transaction analytics: $e');
      }
      return null;
    }
  }

  Stream<TransactionAnalytics?> watchTransactionAnalytics(String orgId, String fy) {
    final fyLabel = _normalizeFyForDocId(fy);
    final docId = 'transactions_${orgId}_$fyLabel';
    return _dataSource.watchAnalyticsDocument(docId).map((payload) {
      if (payload == null) return null;
      return TransactionAnalytics.fromJson(payload);
    });
  }

  /// Document ID: employees_{orgId}_{fy}.
  Future<EmployeesAnalytics?> fetchEmployeesAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'employees_${orgId}_$fyLabel';
      if (kDebugMode) debugPrint('[AnalyticsRepository] Fetching $docId');
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) return null;
      return EmployeesAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching employees analytics: $e');
      return null;
    }
  }

  /// Document ID: vendors_{orgId}_{fy}.
  Future<VendorsAnalytics?> fetchVendorsAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'vendors_${orgId}_$fyLabel';
      if (kDebugMode) debugPrint('[AnalyticsRepository] Fetching $docId');
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) return null;
      return VendorsAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching vendors analytics: $e');
      return null;
    }
  }

  /// Document ID: deliveries_{orgId}_{fy}.
  Future<DeliveriesAnalytics?> fetchDeliveriesAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'deliveries_${orgId}_$fyLabel';
      if (kDebugMode) debugPrint('[AnalyticsRepository] Fetching $docId');
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) return null;
      return DeliveriesAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching deliveries analytics: $e');
      return null;
    }
  }

  /// Document ID: productions_{orgId}_{fy}.
  Future<ProductionsAnalytics?> fetchProductionsAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'productions_${orgId}_$fyLabel';
      if (kDebugMode) debugPrint('[AnalyticsRepository] Fetching $docId');
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) return null;
      return ProductionsAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching productions analytics: $e');
      return null;
    }
  }

  /// Document ID: tripWages_{orgId}_{fy}.
  Future<TripWagesAnalytics?> fetchTripWagesAnalytics(String orgId, String fy) async {
    try {
      final fyLabel = _normalizeFyForDocId(fy);
      final docId = 'tripWages_${orgId}_$fyLabel';
      if (kDebugMode) debugPrint('[AnalyticsRepository] Fetching $docId');
      final payload = await _dataSource.fetchAnalyticsDocument(docId);
      if (payload == null) return null;
      return TripWagesAnalytics.fromMap(payload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching trip wages analytics: $e');
      return null;
    }
  }
}

class TopClientEntry {
  TopClientEntry({
    required this.clientId,
    required this.clientName,
    required this.totalAmount,
    required this.orderCount,
  });
  final String clientId;
  final String clientName;
  final double totalAmount;
  final int orderCount;
}

class DeliveriesAnalytics {
  DeliveriesAnalytics({
    required this.totalQuantityDeliveredMonthly,
    required this.totalQuantityDeliveredYearly,
    required this.quantityByRegion,
    required this.top20ClientsByOrderValueMonthly,
    required this.top20ClientsByOrderValueYearly,
    this.generatedAt,
  });

  factory DeliveriesAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    final totalQtyValues = (map['metrics']?['totalQuantityDeliveredMonthly']?['values'] as Map<String, dynamic>?) ?? {};
    final totalMonthly = totalQtyValues.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final totalQuantityDeliveredYearly = (map['metrics']?['totalQuantityDeliveredYearly'] as num?)?.toInt() ?? 0;

    final quantityByRegionRaw = map['metrics']?['quantityByRegion'] as Map<String, dynamic>? ?? {};
    final quantityByRegion = quantityByRegionRaw.map((region, monthly) {
      final m = monthly as Map<String, dynamic>? ?? {};
      return MapEntry(region, m.map((k, v) => MapEntry(k, (v as num).toDouble())));
    });

    List<TopClientEntry> parseTopClients(dynamic raw) {
      if (raw is! List) return [];
      final list = raw as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return TopClientEntry(
          clientId: m['clientId'] as String? ?? '',
          clientName: m['clientName'] as String? ?? 'Unknown',
          totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
          orderCount: (m['orderCount'] as num?)?.toInt() ?? 0,
        );
      }).toList();
    }

    final top20MonthlyRaw = map['metrics']?['top20ClientsByOrderValueMonthly'] as Map<String, dynamic>? ?? {};
    final top20ClientsByOrderValueMonthly = top20MonthlyRaw.map((month, list) {
      return MapEntry(month, parseTopClients(list));
    });

    final top20YearlyRaw = map['metrics']?['top20ClientsByOrderValueYearly'];
    final top20ClientsByOrderValueYearly = parseTopClients(top20YearlyRaw);

    return DeliveriesAnalytics(
      totalQuantityDeliveredMonthly: totalMonthly,
      totalQuantityDeliveredYearly: totalQuantityDeliveredYearly,
      quantityByRegion: quantityByRegion,
      top20ClientsByOrderValueMonthly: top20ClientsByOrderValueMonthly,
      top20ClientsByOrderValueYearly: top20ClientsByOrderValueYearly,
      generatedAt: generatedAt,
    );
  }

  final Map<String, double> totalQuantityDeliveredMonthly;
  final int totalQuantityDeliveredYearly;
  final Map<String, Map<String, double>> quantityByRegion;
  final Map<String, List<TopClientEntry>> top20ClientsByOrderValueMonthly;
  final List<TopClientEntry> top20ClientsByOrderValueYearly;
  final DateTime? generatedAt;
}

class ProductionsAnalytics {
  ProductionsAnalytics({
    required this.totalProductionMonthly,
    required this.totalProductionYearly,
    required this.totalRawMaterialsMonthly,
    this.generatedAt,
  });

  factory ProductionsAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    Map<String, double> extractValues(String key) {
      final values = map['metrics']?[key]?['values'] as Map<String, dynamic>?;
      if (values == null) return {};
      return values.map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return ProductionsAnalytics(
      totalProductionMonthly: extractValues('totalProductionMonthly'),
      totalProductionYearly: (map['metrics']?['totalProductionYearly'] as num?)?.toInt() ?? 0,
      totalRawMaterialsMonthly: extractValues('totalRawMaterialsMonthly'),
      generatedAt: generatedAt,
    );
  }

  final Map<String, double> totalProductionMonthly;
  final int totalProductionYearly;
  final Map<String, double> totalRawMaterialsMonthly;
  final DateTime? generatedAt;
}

class TripWagesAnalytics {
  TripWagesAnalytics({
    required this.wagesPaidByFixedQuantityMonthly,
    required this.wagesPaidByFixedQuantityYearly,
    required this.totalTripWagesMonthly,
    this.generatedAt,
  });

  factory TripWagesAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    final wagesByQtyMonthlyRaw = map['metrics']?['wagesPaidByFixedQuantityMonthly'] as Map<String, dynamic>? ?? {};
    final wagesPaidByFixedQuantityMonthly = wagesByQtyMonthlyRaw.map((qty, monthly) {
      final m = monthly as Map<String, dynamic>? ?? {};
      return MapEntry(qty, m.map((k, v) => MapEntry(k, (v as num).toDouble())));
    });

    final wagesByQtyYearlyRaw = map['metrics']?['wagesPaidByFixedQuantityYearly'] as Map<String, dynamic>? ?? {};
    final wagesPaidByFixedQuantityYearly = wagesByQtyYearlyRaw.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final totalMonthlyValues = map['metrics']?['totalTripWagesMonthly']?['values'] as Map<String, dynamic>? ?? {};
    final totalTripWagesMonthly = totalMonthlyValues.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return TripWagesAnalytics(
      wagesPaidByFixedQuantityMonthly: wagesPaidByFixedQuantityMonthly,
      wagesPaidByFixedQuantityYearly: wagesPaidByFixedQuantityYearly,
      totalTripWagesMonthly: totalTripWagesMonthly,
      generatedAt: generatedAt,
    );
  }

  final Map<String, Map<String, double>> wagesPaidByFixedQuantityMonthly;
  final Map<String, double> wagesPaidByFixedQuantityYearly;
  final Map<String, double> totalTripWagesMonthly;
  final DateTime? generatedAt;
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

/// Employees analytics: document ID employees_{orgId}_{fy}.
/// Metrics: totalActiveEmployees, wagesCreditMonthly (Map<month, amount>).
class EmployeesAnalytics {
  EmployeesAnalytics({
    required this.totalActiveEmployees,
    required this.wagesCreditMonthly,
    this.generatedAt,
  });

  factory EmployeesAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    Map<String, double> extractSeries(String key) {
      var values = map['metrics']?[key]?['values'];
      if (values == null || (values is Map && values.isEmpty)) {
        final prefix = 'metrics.$key.values.';
        final flatData = <String, double>{};
        map.forEach((mapKey, mapValue) {
          if (mapKey.startsWith(prefix)) {
            final monthKey = mapKey.substring(prefix.length);
            if (mapValue is num) flatData[monthKey] = mapValue.toDouble();
          }
        });
        if (flatData.isNotEmpty) return flatData;
      }
      if (values is Map<String, dynamic>) {
        return values.map((k, v) => MapEntry(k, (v as num).toDouble()));
      }
      return {};
    }

    final totalActiveEmployees = map['metrics']?['totalActiveEmployees'] as num?;
    final totalValue = totalActiveEmployees?.toInt() ?? 0;

    return EmployeesAnalytics(
      totalActiveEmployees: totalValue,
      wagesCreditMonthly: extractSeries('wagesCreditMonthly'),
      generatedAt: generatedAt,
    );
  }

  final int totalActiveEmployees;
  final Map<String, double> wagesCreditMonthly;
  final DateTime? generatedAt;
}

/// Vendors analytics: document ID vendors_{orgId}_{fy}.
/// Metrics: totalPayable, purchasesByVendorType (Map<vendorType, Map<month, amount>>).
class VendorsAnalytics {
  VendorsAnalytics({
    required this.totalPayable,
    required this.purchasesByVendorType,
    this.generatedAt,
  });

  factory VendorsAnalytics.fromMap(Map<String, dynamic> map) {
    final generatedAtRaw = map['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    final totalPayable = (map['metrics']?['totalPayable'] as num?)?.toDouble() ?? 0.0;

    Map<String, Map<String, double>> extractPurchasesByVendorType() {
      var values = map['metrics']?['purchasesByVendorType']?['values'];
      if (values == null || (values is Map && values.isEmpty)) {
        const prefix = 'metrics.purchasesByVendorType.values.';
        final nestedData = <String, Map<String, double>>{};
        map.forEach((mapKey, mapValue) {
          if (mapKey.startsWith(prefix)) {
            final afterPrefix = mapKey.substring(prefix.length);
            final parts = afterPrefix.split('.');
            if (parts.length == 2 && mapValue is num) {
              final vendorType = parts[0];
              final monthKey = parts[1];
              nestedData.putIfAbsent(vendorType, () => {})[monthKey] = mapValue.toDouble();
            }
          }
        });
        if (nestedData.isNotEmpty) return nestedData;
      }
      if (values is Map<String, dynamic>) {
        final result = <String, Map<String, double>>{};
        values.forEach((vendorType, monthlyData) {
          if (monthlyData is Map<String, dynamic>) {
            result[vendorType] = monthlyData.map((k, v) => MapEntry(k, (v as num).toDouble()));
          }
        });
        return result;
      }
      return {};
    }

    return VendorsAnalytics(
      totalPayable: totalPayable,
      purchasesByVendorType: extractPurchasesByVendorType(),
      generatedAt: generatedAt,
    );
  }

  final double totalPayable;
  final Map<String, Map<String, double>> purchasesByVendorType;
  final DateTime? generatedAt;
}


