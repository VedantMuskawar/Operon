import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SystemMetadata extends Equatable {
  final int totalOrganizations;
  final int totalUsers;
  final double totalRevenue;
  final int activeSubscriptions;
  final int lastOrgIdCounter;
  final int lastUserIdCounter;
  final DateTime lastUpdated;

  const SystemMetadata({
    required this.totalOrganizations,
    required this.totalUsers,
    required this.totalRevenue,
    required this.activeSubscriptions,
    required this.lastOrgIdCounter,
    required this.lastUserIdCounter,
    required this.lastUpdated,
  });

  factory SystemMetadata.fromMap(Map<String, dynamic> map) {
    return SystemMetadata(
      totalOrganizations: map['totalOrganizations'] ?? 0,
      totalUsers: map['totalUsers'] ?? 0,
      totalRevenue: (map['totalRevenue'] ?? 0.0).toDouble(),
      activeSubscriptions: map['activeSubscriptions'] ?? 0,
      lastOrgIdCounter: map['lastOrgIdCounter'] ?? 0,
      lastUserIdCounter: map['lastUserIdCounter'] ?? 0,
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrganizations': totalOrganizations,
      'totalUsers': totalUsers,
      'totalRevenue': totalRevenue,
      'activeSubscriptions': activeSubscriptions,
      'lastOrgIdCounter': lastOrgIdCounter,
      'lastUserIdCounter': lastUserIdCounter,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  SystemMetadata copyWith({
    int? totalOrganizations,
    int? totalUsers,
    double? totalRevenue,
    int? activeSubscriptions,
    int? lastOrgIdCounter,
    int? lastUserIdCounter,
    DateTime? lastUpdated,
  }) {
    return SystemMetadata(
      totalOrganizations: totalOrganizations ?? this.totalOrganizations,
      totalUsers: totalUsers ?? this.totalUsers,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      lastOrgIdCounter: lastOrgIdCounter ?? this.lastOrgIdCounter,
      lastUserIdCounter: lastUserIdCounter ?? this.lastUserIdCounter,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        totalOrganizations,
        totalUsers,
        totalRevenue,
        activeSubscriptions,
        lastOrgIdCounter,
        lastUserIdCounter,
        lastUpdated,
      ];
}

// Default system metadata
class DefaultSystemMetadata {
  static SystemMetadata get metadata => SystemMetadata(
        totalOrganizations: 0,
        totalUsers: 0,
        totalRevenue: 0.0,
        activeSubscriptions: 0,
        lastOrgIdCounter: 0,
        lastUserIdCounter: 0,
        lastUpdated: DateTime.now(),
      );
}
