import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

/// Represents the dashboard insights for the CLIENTS data source for a single
/// financial year.
class DashboardClientsYearlyMetadata extends Equatable {
  const DashboardClientsYearlyMetadata({
    required this.financialYearId,
    required this.totalOnboarded,
    required this.totalActiveClientsSnapshot,
    required this.monthlyOnboarding,
    this.createdAt,
    this.updatedAt,
    this.lastEventAt,
  });

  final String financialYearId;
  final int totalOnboarded;
  final int totalActiveClientsSnapshot;
  final Map<String, int> monthlyOnboarding;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastEventAt;

  factory DashboardClientsYearlyMetadata.fromSnapshot(
    String id,
    Map<String, dynamic> data,
  ) {
    return DashboardClientsYearlyMetadata(
      financialYearId: data['financialYearId'] as String? ?? id,
      totalOnboarded: (data['totalOnboarded'] as num?)?.toInt() ?? 0,
      totalActiveClientsSnapshot:
          (data['totalActiveClientsSnapshot'] as num?)?.toInt() ?? 0,
      monthlyOnboarding: _parseMonthlyMap(data['monthlyOnboarding']),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastEventAt: _parseTimestamp(data['lastEventAt']),
    );
  }

  factory DashboardClientsYearlyMetadata.empty(String financialYearId) {
    return DashboardClientsYearlyMetadata(
      financialYearId: financialYearId,
      totalOnboarded: 0,
      totalActiveClientsSnapshot: 0,
      monthlyOnboarding: const {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'financialYearId': financialYearId,
      'totalOnboarded': totalOnboarded,
      'totalActiveClientsSnapshot': totalActiveClientsSnapshot,
      'monthlyOnboarding': monthlyOnboarding,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastEventAt != null) 'lastEventAt': Timestamp.fromDate(lastEventAt!),
    };
  }

  DashboardClientsYearlyMetadata copyWith({
    String? financialYearId,
    int? totalOnboarded,
    int? totalActiveClientsSnapshot,
    Map<String, int>? monthlyOnboarding,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastEventAt,
  }) {
    return DashboardClientsYearlyMetadata(
      financialYearId: financialYearId ?? this.financialYearId,
      totalOnboarded: totalOnboarded ?? this.totalOnboarded,
      totalActiveClientsSnapshot:
          totalActiveClientsSnapshot ?? this.totalActiveClientsSnapshot,
      monthlyOnboarding: monthlyOnboarding ?? this.monthlyOnboarding,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }

  @override
  List<Object?> get props => [
        financialYearId,
        totalOnboarded,
        totalActiveClientsSnapshot,
        monthlyOnboarding,
        createdAt,
        updatedAt,
        lastEventAt,
      ];
}

/// Represents the aggregate summary document for CLIENTS dashboard metadata.
class DashboardClientsSummary extends Equatable {
  const DashboardClientsSummary({
    required this.totalActiveClients,
    this.createdAt,
    this.updatedAt,
    this.lastEventAt,
  });

  final int totalActiveClients;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastEventAt;

  factory DashboardClientsSummary.fromSnapshot(Map<String, dynamic> data) {
    return DashboardClientsSummary(
      totalActiveClients: (data['totalActiveClients'] as num?)?.toInt() ?? 0,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastEventAt: _parseTimestamp(data['lastEventAt']),
    );
  }

  factory DashboardClientsSummary.empty() {
    return const DashboardClientsSummary(totalActiveClients: 0);
  }

  Map<String, dynamic> toMap() {
    return {
      'totalActiveClients': totalActiveClients,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (lastEventAt != null) 'lastEventAt': Timestamp.fromDate(lastEventAt!),
    };
  }

  DashboardClientsSummary copyWith({
    int? totalActiveClients,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastEventAt,
  }) {
    return DashboardClientsSummary(
      totalActiveClients: totalActiveClients ?? this.totalActiveClients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastEventAt: lastEventAt ?? this.lastEventAt,
    );
  }

  @override
  List<Object?> get props => [
        totalActiveClients,
        createdAt,
        updatedAt,
        lastEventAt,
      ];
}

Map<String, int> _parseMonthlyMap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw.map(
      (key, value) => MapEntry(
        key,
        (value as num?)?.toInt() ?? 0,
      ),
    );
  }
  return const {};
}

DateTime? _parseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

