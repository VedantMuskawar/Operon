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
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      if (organizationId == null || organizationId.isEmpty) {
        return null;
      }

      // Determine date range
      DateTime effectiveStartDate;
      DateTime effectiveEndDate;
      
      if (startDate != null && endDate != null) {
        effectiveStartDate = startDate;
        effectiveEndDate = endDate;
      } else if (financialYear != null) {
        final fyLabel = _normalizeFyForDocId(financialYear);
        final match = RegExp(r'FY(\d{2})(\d{2})').firstMatch(fyLabel);
        if (match != null) {
          final startYear = 2000 + int.parse(match.group(1)!);
          effectiveStartDate = DateTime(startYear, 4, 1);
          effectiveEndDate = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        } else {
          final now = asOf ?? DateTime.now();
          final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
          effectiveStartDate = DateTime(fyStartYear, 4, 1);
          effectiveEndDate = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
        }
      } else {
        final now = asOf ?? DateTime.now();
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        effectiveStartDate = DateTime(fyStartYear, 4, 1);
        effectiveEndDate = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
      }

      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;

      final docIds = months.map((month) => 'clients_${organizationId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;

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

      return ClientsAnalytics.fromMap(aggregatedPayload);
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

  /// Fetches transaction analytics for the given org and date range.
  /// Fetches multiple monthly documents and aggregates them.
  /// Document ID format: transactions_{orgId}_{YYYY-MM} (e.g. transactions_abc123_2024-04).
  Future<TransactionAnalytics?> fetchTransactionAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Determine date range
      DateTime effectiveStartDate;
      DateTime effectiveEndDate;
      
      if (startDate != null && endDate != null) {
        effectiveStartDate = startDate;
        effectiveEndDate = endDate;
      } else if (financialYear != null) {
        // Calculate FY dates from FY label
        final fyLabel = _normalizeFyForDocId(financialYear);
        final match = RegExp(r'FY(\d{2})(\d{2})').firstMatch(fyLabel);
        if (match != null) {
          final startYear = 2000 + int.parse(match.group(1)!);
          effectiveStartDate = DateTime(startYear, 4, 1);
          effectiveEndDate = DateTime(startYear + 1, 3, 31, 23, 59, 59);
        } else {
          // Fallback to current FY
          final now = DateTime.now();
          final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
          effectiveStartDate = DateTime(fyStartYear, 4, 1);
          effectiveEndDate = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
        }
      } else {
        // Default to current FY
        final now = DateTime.now();
        final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
        effectiveStartDate = DateTime(fyStartYear, 4, 1);
        effectiveEndDate = DateTime(fyStartYear + 1, 3, 31, 23, 59, 59);
      }

      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;

      final docIds = months.map((month) => 'transactions_${orgId}_$month').toList();
      
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Fetching transaction analytics for months: $months');
      }
      
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) {
        if (kDebugMode) {
          debugPrint('[AnalyticsRepository] No transaction analytics documents found');
        }
        return null;
      }

      // Aggregate data from multiple monthly documents
      return _aggregateTransactionAnalytics(docs);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AnalyticsRepository] Error fetching transaction analytics: $e');
      }
      return null;
    }
  }

  /// Aggregate transaction analytics from multiple monthly documents
  TransactionAnalytics _aggregateTransactionAnalytics(List<Map<String, dynamic>> docs) {
    final incomeDaily = <String, double>{};
    final receivablesDaily = <String, double>{};
    final incomeWeekly = <String, double>{};
    final receivablesWeekly = <String, double>{};
    final incomeMonthly = <String, double>{};
    final receivablesMonthly = <String, double>{};
    final incomeByCategory = <String, double>{};
    final receivablesByCategory = <String, double>{};
    final byType = <String, Map<String, dynamic>>{};
    final byPaymentAccount = <String, Map<String, dynamic>>{};
    final byPaymentMethodType = <String, Map<String, dynamic>>{};
    var totalIncome = 0.0;
    var totalReceivables = 0.0;
    var transactionCount = 0;
    final receivableAging = <String, double>{
      'current': 0.0,
      'days31to60': 0.0,
      'days61to90': 0.0,
      'over90': 0.0,
    };
    DateTime? lastUpdated;

    for (final doc in docs) {
      // Aggregate daily data
      if (doc['incomeDaily'] is Map) {
        (doc['incomeDaily'] as Map).forEach((key, value) {
          incomeDaily[key.toString()] = (incomeDaily[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }
      if (doc['receivablesDaily'] is Map) {
        (doc['receivablesDaily'] as Map).forEach((key, value) {
          receivablesDaily[key.toString()] = (receivablesDaily[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }

      // Aggregate weekly data
      if (doc['incomeWeekly'] is Map) {
        (doc['incomeWeekly'] as Map).forEach((key, value) {
          incomeWeekly[key.toString()] = (incomeWeekly[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }
      if (doc['receivablesWeekly'] is Map) {
        (doc['receivablesWeekly'] as Map).forEach((key, value) {
          receivablesWeekly[key.toString()] = (receivablesWeekly[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }

      // Aggregate monthly data (from month field or calculate from daily)
      final month = doc['month'] as String?;
      if (month != null) {
        final monthIncome = (doc['totalIncome'] as num?)?.toDouble() ?? 0.0;
        final monthReceivables = (doc['totalReceivables'] as num?)?.toDouble() ?? 0.0;
        incomeMonthly[month] = (incomeMonthly[month] ?? 0.0) + monthIncome;
        receivablesMonthly[month] = (receivablesMonthly[month] ?? 0.0) + monthReceivables;
      }

      // Aggregate category data
      if (doc['incomeByCategory'] is Map) {
        (doc['incomeByCategory'] as Map).forEach((key, value) {
          incomeByCategory[key.toString()] = (incomeByCategory[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }
      if (doc['receivablesByCategory'] is Map) {
        (doc['receivablesByCategory'] as Map).forEach((key, value) {
          receivablesByCategory[key.toString()] = (receivablesByCategory[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }

      // Aggregate by type
      if (doc['byType'] is Map) {
        (doc['byType'] as Map).forEach((typeKey, typeData) {
          if (typeData is Map) {
            if (!byType.containsKey(typeKey.toString())) {
              byType[typeKey.toString()] = {
                'count': 0,
                'total': 0.0,
                'daily': <String, double>{},
                'weekly': <String, double>{},
              };
            }
            byType[typeKey.toString()]!['count'] = (byType[typeKey.toString()]!['count'] as int) + ((typeData['count'] as num?)?.toInt() ?? 0);
            byType[typeKey.toString()]!['total'] = (byType[typeKey.toString()]!['total'] as double) + ((typeData['total'] as num?)?.toDouble() ?? 0.0);
            if (typeData['daily'] is Map) {
              (typeData['daily'] as Map).forEach((dayKey, dayValue) {
                final dailyMap = byType[typeKey.toString()]!['daily'] as Map<String, double>;
                dailyMap[dayKey.toString()] = (dailyMap[dayKey.toString()] ?? 0.0) + (dayValue as num).toDouble();
              });
            }
            if (typeData['weekly'] is Map) {
              (typeData['weekly'] as Map).forEach((weekKey, weekValue) {
                final weeklyMap = byType[typeKey.toString()]!['weekly'] as Map<String, double>;
                weeklyMap[weekKey.toString()] = (weeklyMap[weekKey.toString()] ?? 0.0) + (weekValue as num).toDouble();
              });
            }
          }
        });
      }

      // Aggregate totals
      totalIncome += (doc['totalIncome'] as num?)?.toDouble() ?? 0.0;
      totalReceivables += (doc['totalReceivables'] as num?)?.toDouble() ?? 0.0;
      transactionCount += (doc['transactionCount'] as num?)?.toInt() ?? 0;

      // Aggregate receivable aging
      if (doc['receivableAging'] is Map) {
        (doc['receivableAging'] as Map).forEach((key, value) {
          receivableAging[key.toString()] = (receivableAging[key.toString()] ?? 0.0) + (value as num).toDouble();
        });
      }

      // Track latest lastUpdated
      if (doc['lastUpdated'] != null) {
        final docLastUpdated = doc['lastUpdated'] is Timestamp
            ? (doc['lastUpdated'] as Timestamp).toDate()
            : (doc['lastUpdated'] is DateTime ? doc['lastUpdated'] as DateTime : null);
        if (docLastUpdated != null && (lastUpdated == null || docLastUpdated.isAfter(lastUpdated))) {
          lastUpdated = docLastUpdated;
        }
      }
    }

    // Build monthly maps from aggregated daily data grouped by month
    final incomeMonthlyFromDaily = <String, double>{};
    final receivablesMonthlyFromDaily = <String, double>{};
    
    incomeDaily.forEach((dateKey, value) {
      if (dateKey.length >= 7) {
        final monthKey = dateKey.substring(0, 7); // YYYY-MM
        incomeMonthlyFromDaily[monthKey] = (incomeMonthlyFromDaily[monthKey] ?? 0.0) + value;
      }
    });
    
    receivablesDaily.forEach((dateKey, value) {
      if (dateKey.length >= 7) {
        final monthKey = dateKey.substring(0, 7); // YYYY-MM
        receivablesMonthlyFromDaily[monthKey] = (receivablesMonthlyFromDaily[monthKey] ?? 0.0) + value;
      }
    });

    // Use monthly maps from daily aggregation, fallback to stored monthly values
    final finalIncomeMonthly = incomeMonthlyFromDaily.isNotEmpty ? incomeMonthlyFromDaily : incomeMonthly;
    final finalReceivablesMonthly = receivablesMonthlyFromDaily.isNotEmpty ? receivablesMonthlyFromDaily : receivablesMonthly;

    final aggregatedPayload = {
      'source': 'transactions',
      'incomeDaily': incomeDaily,
      'receivablesDaily': receivablesDaily,
      'incomeWeekly': incomeWeekly,
      'receivablesWeekly': receivablesWeekly,
      'incomeMonthly': finalIncomeMonthly,
      'receivablesMonthly': finalReceivablesMonthly,
      'incomeByCategory': incomeByCategory,
      'receivablesByCategory': receivablesByCategory,
      'byType': byType,
      'byPaymentAccount': byPaymentAccount,
      'byPaymentMethodType': byPaymentMethodType,
      'totalIncome': totalIncome,
      'totalReceivables': totalReceivables,
      'netReceivables': totalReceivables - totalIncome,
      'receivableAging': receivableAging,
      'transactionCount': transactionCount,
      if (lastUpdated != null) 'lastUpdated': Timestamp.fromDate(lastUpdated),
    };

    return TransactionAnalytics.fromJson(aggregatedPayload);
  }

  Stream<TransactionAnalytics?> watchTransactionAnalytics(String orgId, String fy) {
    final fyLabel = _normalizeFyForDocId(fy);
    final docId = 'transactions_${orgId}_$fyLabel';
    return _dataSource.watchAnalyticsDocument(docId).map((payload) {
      if (payload == null) return null;
      return TransactionAnalytics.fromJson(payload);
    });
  }

  /// Helper to calculate date range from financial year or use provided dates
  (DateTime, DateTime) _calculateDateRange({
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    if (startDate != null && endDate != null) {
      return (startDate, endDate);
    }
    if (financialYear != null) {
      final fyLabel = _normalizeFyForDocId(financialYear);
      final match = RegExp(r'FY(\d{2})(\d{2})').firstMatch(fyLabel);
      if (match != null) {
        final startYear = 2000 + int.parse(match.group(1)!);
        return (DateTime(startYear, 4, 1), DateTime(startYear + 1, 3, 31, 23, 59, 59));
      }
    }
    // Default to current FY
    final now = DateTime.now();
    final fyStartYear = now.month >= 4 ? now.year : now.year - 1;
    return (DateTime(fyStartYear, 4, 1), DateTime(fyStartYear + 1, 3, 31, 23, 59, 59));
  }

  /// Document ID: employees_{orgId}_{YYYY-MM}.
  Future<EmployeesAnalytics?> fetchEmployeesAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
      );
      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;
      final docIds = months.map((month) => 'employees_${orgId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;
      
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
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching employees analytics: $e');
      return null;
    }
  }

  /// Document ID: vendors_{orgId}_{YYYY-MM}.
  Future<VendorsAnalytics?> fetchVendorsAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
      );
      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;
      final docIds = months.map((month) => 'vendors_${orgId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;
      
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
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching vendors analytics: $e');
      return null;
    }
  }

  /// Document ID: deliveries_{orgId}_{YYYY-MM}.
  Future<DeliveriesAnalytics?> fetchDeliveriesAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
      );
      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;
      final docIds = months.map((month) => 'deliveries_${orgId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;
      
      // Aggregate: sum quantities, merge regions, merge top clients
      final totalQuantityDeliveredMonthly = <String, double>{};
      final quantityByRegion = <String, Map<String, double>>{};
      final top20ClientsByOrderValueMonthly = <String, List<TopClientEntry>>{};
      var totalQuantityDeliveredYearly = 0.0;
      
      for (final doc in docs) {
        final month = doc['month'] as String?;
        final qty = (doc['metrics']?['totalQuantityDeliveredMonthly'] as num?)?.toDouble() ?? 0.0;
        if (month != null && qty > 0) {
          totalQuantityDeliveredMonthly[month] = (totalQuantityDeliveredMonthly[month] ?? 0.0) + qty;
          totalQuantityDeliveredYearly += qty;
        }
        final regions = doc['metrics']?['quantityByRegion'] as Map<String, dynamic>?;
        if (regions != null && month != null) {
          regions.forEach((region, qtyValue) {
            if (qtyValue is num) {
              quantityByRegion.putIfAbsent(region, () => <String, double>{});
              quantityByRegion[region]![month] = 
                (quantityByRegion[region]![month] ?? 0.0) + qtyValue.toDouble();
            }
          });
        }
        final topClients = doc['metrics']?['top20ClientsByOrderValueMonthly'] as List<dynamic>?;
        if (topClients != null && month != null) {
          top20ClientsByOrderValueMonthly[month] = topClients.map((e) {
            final m = e as Map<String, dynamic>;
            return TopClientEntry(
              clientId: m['clientId'] as String? ?? '',
              clientName: m['clientName'] as String? ?? 'Unknown',
              totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
              orderCount: (m['orderCount'] as num?)?.toInt() ?? 0,
            );
          }).toList();
        }
      }
      
      final aggregatedPayload = {
        'metrics': {
          'totalQuantityDeliveredMonthly': {'values': totalQuantityDeliveredMonthly},
          'totalQuantityDeliveredYearly': totalQuantityDeliveredYearly.toInt(),
          'quantityByRegion': quantityByRegion,
          'top20ClientsByOrderValueMonthly': top20ClientsByOrderValueMonthly,
          'top20ClientsByOrderValueYearly': <TopClientEntry>[], // Calculate from monthly if needed
        },
        'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
      };
      return DeliveriesAnalytics.fromMap(aggregatedPayload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching deliveries analytics: $e');
      return null;
    }
  }

  /// Document ID: productions_{orgId}_{YYYY-MM}.
  Future<ProductionsAnalytics?> fetchProductionsAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
      );
      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;
      final docIds = months.map((month) => 'productions_${orgId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;
      
      // Aggregate: sum production and raw materials by month
      final totalProductionMonthly = <String, double>{};
      final totalRawMaterialsMonthly = <String, double>{};
      var totalProductionYearly = 0.0;
      
      for (final doc in docs) {
        final month = doc['month'] as String?;
        final production = (doc['metrics']?['totalProductionMonthly'] as num?)?.toDouble() ?? 0.0;
        final rawMaterials = (doc['metrics']?['totalRawMaterialsMonthly'] as num?)?.toDouble() ?? 0.0;
        if (month != null) {
          if (production > 0) {
            totalProductionMonthly[month] = (totalProductionMonthly[month] ?? 0.0) + production;
            totalProductionYearly += production;
          }
          if (rawMaterials > 0) {
            totalRawMaterialsMonthly[month] = (totalRawMaterialsMonthly[month] ?? 0.0) + rawMaterials;
          }
        }
      }
      
      final aggregatedPayload = {
        'metrics': {
          'totalProductionMonthly': {'values': totalProductionMonthly},
          'totalProductionYearly': totalProductionYearly.toInt(),
          'totalRawMaterialsMonthly': {'values': totalRawMaterialsMonthly},
        },
        'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
      };
      return ProductionsAnalytics.fromMap(aggregatedPayload);
    } catch (e) {
      if (kDebugMode) debugPrint('[AnalyticsRepository] Error fetching productions analytics: $e');
      return null;
    }
  }

  /// Document ID: tripWages_{orgId}_{YYYY-MM}.
  Future<TripWagesAnalytics?> fetchTripWagesAnalytics(
    String orgId, {
    String? financialYear,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final (effectiveStartDate, effectiveEndDate) = _calculateDateRange(
        financialYear: financialYear,
        startDate: startDate,
        endDate: endDate,
      );
      final months = _getMonthsInRange(effectiveStartDate, effectiveEndDate);
      if (months.isEmpty) return null;
      final docIds = months.map((month) => 'tripWages_${orgId}_$month').toList();
      final docs = await _dataSource.fetchAnalyticsDocuments(docIds);
      if (docs.isEmpty) return null;
      
      // Aggregate: sum wages by month and quantity
      final totalTripWagesMonthly = <String, double>{};
      final wagesPaidByFixedQuantityMonthly = <String, Map<String, double>>{};
      final wagesPaidByFixedQuantityYearly = <String, double>{};
      
      for (final doc in docs) {
        final month = doc['month'] as String?;
        final totalWages = (doc['metrics']?['totalTripWagesMonthly'] as num?)?.toDouble() ?? 0.0;
        if (month != null && totalWages > 0) {
          totalTripWagesMonthly[month] = (totalTripWagesMonthly[month] ?? 0.0) + totalWages;
        }
        final wagesByQty = doc['metrics']?['wagesPaidByFixedQuantityMonthly'] as Map<String, dynamic>?;
        if (wagesByQty != null && month != null) {
          wagesByQty.forEach((qtyKey, amount) {
            if (amount is num) {
              wagesPaidByFixedQuantityMonthly.putIfAbsent(qtyKey, () => <String, double>{});
              wagesPaidByFixedQuantityMonthly[qtyKey]![month] = 
                (wagesPaidByFixedQuantityMonthly[qtyKey]![month] ?? 0.0) + amount.toDouble();
              wagesPaidByFixedQuantityYearly[qtyKey] = 
                (wagesPaidByFixedQuantityYearly[qtyKey] ?? 0.0) + amount.toDouble();
            }
          });
        }
      }
      
      final aggregatedPayload = {
        'metrics': {
          'totalTripWagesMonthly': {'values': totalTripWagesMonthly},
          'wagesPaidByFixedQuantityMonthly': wagesPaidByFixedQuantityMonthly,
          'wagesPaidByFixedQuantityYearly': wagesPaidByFixedQuantityYearly,
        },
        'generatedAt': docs.isNotEmpty ? docs.last['generatedAt'] : null,
      };
      return TripWagesAnalytics.fromMap(aggregatedPayload);
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


