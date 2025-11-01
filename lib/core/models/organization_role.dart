import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class OrganizationRole extends Equatable {
  final String orgId;
  final int role;
  final String status;
  final DateTime? joinedDate;
  final bool isPrimary;
  final List<String> permissions;

  const OrganizationRole({
    required this.orgId,
    required this.role,
    required this.status,
    this.joinedDate,
    required this.isPrimary,
    this.permissions = const [],
  });

  factory OrganizationRole.fromMap(Map<String, dynamic> map) {
    return OrganizationRole(
      orgId: map['orgId'] ?? '',
      role: map['role'] ?? 1,
      status: map['status'] ?? 'active',
      joinedDate: map['joinedDate'] != null 
          ? (map['joinedDate'] as Timestamp).toDate()
          : null,
      isPrimary: map['isPrimary'] ?? false,
      permissions: (map['permissions'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'role': role,
      'status': status,
      if (joinedDate != null) 'joinedDate': Timestamp.fromDate(joinedDate!),
      'isPrimary': isPrimary,
      'permissions': permissions,
    };
  }

  @override
  List<Object?> get props => [orgId, role, status, joinedDate, isPrimary, permissions];
}
