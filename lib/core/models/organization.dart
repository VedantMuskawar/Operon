import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'subscription.dart';

class Organization extends Equatable {
  final String orgId;
  final String orgName;
  final String email;
  final String gstNo;
  final String? orgLogoUrl;
  final String status;
  final DateTime createdDate;
  final DateTime updatedDate;
  final String createdBy;
  final OrganizationMetadata metadata;
  final Subscription? subscription; // Optional subscription data

  const Organization({
    required this.orgId,
    required this.orgName,
    required this.email,
    required this.gstNo,
    this.orgLogoUrl,
    required this.status,
    required this.createdDate,
    required this.updatedDate,
    required this.createdBy,
    required this.metadata,
    this.subscription,
  });

  factory Organization.fromMap(Map<String, dynamic> map) {
    return Organization(
      orgId: map['orgId'] ?? '',
      orgName: map['orgName'] ?? '',
      email: map['email'] ?? '',
      gstNo: map['gstNo'] ?? '',
      orgLogoUrl: map['orgLogoUrl'],
      status: map['status'] ?? 'active',
      createdDate: map['createdDate'] != null 
          ? (map['createdDate'] as Timestamp).toDate()
          : DateTime.now(),
      updatedDate: map['updatedDate'] != null 
          ? (map['updatedDate'] as Timestamp).toDate()
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      metadata: OrganizationMetadata.fromMap(map['metadata'] ?? {}),
      subscription: map['subscription'] != null 
          ? Subscription.fromMap(map['subscription'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'orgName': orgName,
      'email': email,
      'gstNo': gstNo,
      'orgLogoUrl': orgLogoUrl,
      'status': status,
      'createdDate': Timestamp.fromDate(createdDate),
      'updatedDate': Timestamp.fromDate(updatedDate),
      'createdBy': createdBy,
      'metadata': metadata.toMap(),
      if (subscription != null) 'subscription': subscription!.toMap(),
    };
  }

  Organization copyWith({
    String? orgId,
    String? orgName,
    String? email,
    String? gstNo,
    String? orgLogoUrl,
    String? status,
    DateTime? createdDate,
    DateTime? updatedDate,
    String? createdBy,
    OrganizationMetadata? metadata,
    Subscription? subscription,
  }) {
    return Organization(
      orgId: orgId ?? this.orgId,
      orgName: orgName ?? this.orgName,
      email: email ?? this.email,
      gstNo: gstNo ?? this.gstNo,
      orgLogoUrl: orgLogoUrl ?? this.orgLogoUrl,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      createdBy: createdBy ?? this.createdBy,
      metadata: metadata ?? this.metadata,
      subscription: subscription ?? this.subscription,
    );
  }

  @override
  List<Object?> get props => [
        orgId,
        orgName,
        email,
        gstNo,
        orgLogoUrl,
        status,
        createdDate,
        updatedDate,
        createdBy,
        metadata,
        subscription,
      ];
}

class OrganizationMetadata extends Equatable {
  final int totalUsers;
  final int activeUsers;
  final String? industry;
  final String? location;

  const OrganizationMetadata({
    required this.totalUsers,
    required this.activeUsers,
    this.industry,
    this.location,
  });

  factory OrganizationMetadata.fromMap(Map<String, dynamic> map) {
    return OrganizationMetadata(
      totalUsers: map['totalUsers'] ?? 0,
      activeUsers: map['activeUsers'] ?? 0,
      industry: map['industry'],
      location: map['location'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalUsers': totalUsers,
      'activeUsers': activeUsers,
      'industry': industry,
      'location': location,
    };
  }

  @override
  List<Object?> get props => [totalUsers, activeUsers, industry, location];
}
