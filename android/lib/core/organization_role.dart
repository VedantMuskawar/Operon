import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class OrganizationRole extends Equatable {
  final String orgId;
  final int role;
  final DateTime? joinedDate;

  const OrganizationRole({
    required this.orgId,
    required this.role,
    this.joinedDate,
  });

  factory OrganizationRole.fromMap(Map<String, dynamic> map) {
    return OrganizationRole(
      orgId: map['orgId'] ?? '',
      role: map['role'] ?? 1,
      joinedDate: map['joinedDate'] != null 
          ? (map['joinedDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'role': role,
      if (joinedDate != null) 'joinedDate': Timestamp.fromDate(joinedDate!),
    };
  }

  @override
  List<Object?> get props => [orgId, role, joinedDate];
}



