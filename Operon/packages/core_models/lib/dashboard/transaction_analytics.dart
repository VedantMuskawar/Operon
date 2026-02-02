import 'package:cloud_firestore/cloud_firestore.dart';

/// Receivable aging buckets (e.g. current, 31–60 days, 61–90 days, 90+).
/// Parsed from Firestore; exposes typed getters and a map for donut chart iteration.
class ReceivableAging {
  const ReceivableAging({
    this.current = 0.0,
    this.days31to60 = 0.0,
    this.days61to90 = 0.0,
    this.daysOver90 = 0.0,
    this.values = const {},
  });

  final double current;
  final double days31to60;
  final double days61to90;
  final double daysOver90;

  /// Raw key → value map for any additional or varying bucket names from Firestore.
  final Map<String, double> values;

  /// Non-zero entries for chart display (current, days31to60, days61to90, daysOver90 + values).
  Map<String, double> get nonZeroEntries {
    final map = <String, double>{
      if (current != 0) 'current': current,
      if (days31to60 != 0) 'days31to60': days31to60,
      if (days61to90 != 0) 'days61to90': days61to90,
      if (daysOver90 != 0) 'daysOver90': daysOver90,
      ...values,
    };
    return Map.fromEntries(map.entries.where((e) => e.value != 0));
  }

  double get total =>
      current + days31to60 + days61to90 + daysOver90 + values.values.fold(0.0, (a, b) => a + b);

  static double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0.0 : 0.0);

  factory ReceivableAging.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const ReceivableAging();
    }
    final current = _toDouble(map['current']);
    final days31to60 = _toDouble(map['days31to60']);
    final days61to90 = _toDouble(map['days61to90']);
    final daysOver90 = _toDouble(map['daysOver90']);
    final knownKeys = {'current', 'days31to60', 'days61to90', 'daysOver90'};
    final values = <String, double>{};
    for (final e in map.entries) {
      if (knownKeys.contains(e.key)) continue;
      values[e.key] = _toDouble(e.value);
    }
    return ReceivableAging(
      current: current,
      days31to60: days31to60,
      days61to90: days61to90,
      daysOver90: daysOver90,
      values: values,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current': current,
      'days31to60': days31to60,
      'days61to90': days61to90,
      'daysOver90': daysOver90,
      ...values.map((k, v) => MapEntry(k, v)),
    };
  }
}

/// Transaction analytics for a given org + FY (document: transactions_{orgId}_{FY}).
class TransactionAnalytics {
  const TransactionAnalytics({
    required this.incomeDaily,
    required this.receivablesDaily,
    required this.incomeMonthly,
    required this.receivablesMonthly,
    required this.receivableAging,
    required this.totalIncome,
    required this.totalReceivables,
    this.netReceivables,
    this.generatedAt,
  });

  final Map<String, double> incomeDaily;
  final Map<String, double> receivablesDaily;
  final Map<String, double> incomeMonthly;
  final Map<String, double> receivablesMonthly;
  final ReceivableAging receivableAging;
  final double totalIncome;
  final double totalReceivables;
  final double? netReceivables;
  final DateTime? generatedAt;

  static Map<String, double> _parseNumberMap(dynamic source) {
    if (source == null) return {};
    if (source is! Map) return {};
    return source.map<String, double>(
      (k, v) => MapEntry(k.toString(), v is num ? v.toDouble() : (v is String ? double.tryParse(v) ?? 0.0 : 0.0)),
    );
  }

  factory TransactionAnalytics.fromJson(Map<String, dynamic> json) {
    final generatedAtRaw = json['generatedAt'];
    final generatedAt = generatedAtRaw is Timestamp
        ? generatedAtRaw.toDate()
        : (generatedAtRaw is DateTime ? generatedAtRaw : null);

    final totalIncome = (json['totalIncome'] is num)
        ? (json['totalIncome'] as num).toDouble()
        : 0.0;
    final totalReceivables = (json['totalReceivables'] is num)
        ? (json['totalReceivables'] as num).toDouble()
        : 0.0;
    final netReceivables = json['netReceivables'] != null && json['netReceivables'] is num
        ? (json['netReceivables'] as num).toDouble()
        : null;

    final receivableAging = ReceivableAging.fromMap(
      json['receivableAging'] as Map<String, dynamic>?,
    );

    return TransactionAnalytics(
      incomeDaily: _parseNumberMap(json['incomeDaily']),
      receivablesDaily: _parseNumberMap(json['receivablesDaily']),
      incomeMonthly: _parseNumberMap(json['incomeMonthly']),
      receivablesMonthly: _parseNumberMap(json['receivablesMonthly']),
      receivableAging: receivableAging,
      totalIncome: totalIncome,
      totalReceivables: totalReceivables,
      netReceivables: netReceivables,
      generatedAt: generatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incomeDaily': incomeDaily,
      'receivablesDaily': receivablesDaily,
      'incomeMonthly': incomeMonthly,
      'receivablesMonthly': receivablesMonthly,
      'receivableAging': receivableAging.toMap(),
      'totalIncome': totalIncome,
      'totalReceivables': totalReceivables,
      if (netReceivables != null) 'netReceivables': netReceivables,
      if (generatedAt != null) 'generatedAt': Timestamp.fromDate(generatedAt!),
    };
  }
}
