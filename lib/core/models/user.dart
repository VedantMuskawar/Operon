import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'organization_role.dart';

class User extends Equatable {
  final String userId;
  final String name;
  final String phoneNo;
  final String email;
  final String? profilePhotoUrl;
  final String status;
  final DateTime createdDate;
  final DateTime updatedDate;
  final DateTime? lastLoginDate;
  final UserMetadata metadata;
  final List<OrganizationRole> organizations;

  const User({
    required this.userId,
    required this.name,
    required this.phoneNo,
    required this.email,
    this.profilePhotoUrl,
    required this.status,
    required this.createdDate,
    required this.updatedDate,
    this.lastLoginDate,
    required this.metadata,
    this.organizations = const [],
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      phoneNo: map['phoneNo'] ?? '',
      email: map['email'] ?? '',
      profilePhotoUrl: map['profilePhotoUrl'],
      status: map['status'] ?? 'active',
      createdDate: (map['createdDate'] as Timestamp).toDate(),
      updatedDate: (map['updatedDate'] as Timestamp).toDate(),
      lastLoginDate: map['lastLoginDate'] != null 
          ? (map['lastLoginDate'] as Timestamp).toDate()
          : null,
      metadata: UserMetadata.fromMap(map['metadata'] ?? {}),
      organizations: (map['organizations'] as List<dynamic>?)
          ?.map((org) => OrganizationRole.fromMap(org))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'phoneNo': phoneNo,
      'email': email,
      'profilePhotoUrl': profilePhotoUrl,
      'status': status,
      'createdDate': Timestamp.fromDate(createdDate),
      'updatedDate': Timestamp.fromDate(updatedDate),
      'lastLoginDate': lastLoginDate != null 
          ? Timestamp.fromDate(lastLoginDate!)
          : null,
      'metadata': metadata.toMap(),
      'organizations': organizations.map((org) => org.toMap()).toList(),
    };
  }

  User copyWith({
    String? userId,
    String? name,
    String? phoneNo,
    String? email,
    String? profilePhotoUrl,
    String? status,
    DateTime? createdDate,
    DateTime? updatedDate,
    DateTime? lastLoginDate,
    UserMetadata? metadata,
    List<OrganizationRole>? organizations,
  }) {
    return User(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNo: phoneNo ?? this.phoneNo,
      email: email ?? this.email,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      status: status ?? this.status,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      metadata: metadata ?? this.metadata,
      organizations: organizations ?? this.organizations,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        phoneNo,
        email,
        profilePhotoUrl,
        status,
        createdDate,
        updatedDate,
        lastLoginDate,
        metadata,
        organizations,
      ];
}

class UserMetadata extends Equatable {
  final int totalOrganizations;
  final String? primaryOrgId;
  final Map<String, dynamic> notificationPreferences;

  const UserMetadata({
    required this.totalOrganizations,
    this.primaryOrgId,
    required this.notificationPreferences,
  });

  factory UserMetadata.fromMap(Map<String, dynamic> map) {
    return UserMetadata(
      totalOrganizations: map['totalOrganizations'] ?? 0,
      primaryOrgId: map['primaryOrgId'],
      notificationPreferences: Map<String, dynamic>.from(
        map['notificationPreferences'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalOrganizations': totalOrganizations,
      'primaryOrgId': primaryOrgId,
      'notificationPreferences': notificationPreferences,
    };
  }

  @override
  List<Object?> get props => [totalOrganizations, primaryOrgId, notificationPreferences];
}

class OrganizationUser extends Equatable {
  final String userId;
  final int role;
  final String name;
  final String phoneNo;
  final String email;
  final String status;
  final DateTime addedDate;
  final DateTime updatedDate;
  final String addedBy;
  final List<String> permissions;

  const OrganizationUser({
    required this.userId,
    required this.role,
    required this.name,
    required this.phoneNo,
    required this.email,
    required this.status,
    required this.addedDate,
    required this.updatedDate,
    required this.addedBy,
    required this.permissions,
  });

  factory OrganizationUser.fromMap(Map<String, dynamic> map) {
    return OrganizationUser(
      userId: map['userId'] ?? '',
      role: map['role'] ?? 1,
      name: map['name'] ?? '',
      phoneNo: map['phoneNo'] ?? '',
      email: map['email'] ?? '',
      status: map['status'] ?? 'active',
      addedDate: (map['addedDate'] as Timestamp).toDate(),
      updatedDate: (map['updatedDate'] as Timestamp).toDate(),
      addedBy: map['addedBy'] ?? '',
      permissions: List<String>.from(map['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'role': role,
      'name': name,
      'phoneNo': phoneNo,
      'email': email,
      'status': status,
      'addedDate': Timestamp.fromDate(addedDate),
      'updatedDate': Timestamp.fromDate(updatedDate),
      'addedBy': addedBy,
      'permissions': permissions,
    };
  }

  @override
  List<Object?> get props => [
        userId,
        role,
        name,
        phoneNo,
        email,
        status,
        addedDate,
        updatedDate,
        addedBy,
        permissions,
      ];
}

class UserOrganization extends Equatable {
  final String orgId;
  final String orgName;
  final String? orgLogoUrl;
  final int role;
  final String status;
  final DateTime joinedDate;
  final bool isPrimary;
  final List<String> permissions;

  const UserOrganization({
    required this.orgId,
    required this.orgName,
    this.orgLogoUrl,
    required this.role,
    required this.status,
    required this.joinedDate,
    required this.isPrimary,
    required this.permissions,
  });

  factory UserOrganization.fromMap(Map<String, dynamic> map) {
    return UserOrganization(
      orgId: map['orgId'] ?? '',
      orgName: map['orgName'] ?? '',
      orgLogoUrl: map['orgLogoUrl'],
      role: map['role'] ?? 1,
      status: map['status'] ?? 'active',
      joinedDate: (map['joinedDate'] as Timestamp).toDate(),
      isPrimary: map['isPrimary'] ?? false,
      permissions: List<String>.from(map['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orgId': orgId,
      'orgName': orgName,
      'orgLogoUrl': orgLogoUrl,
      'role': role,
      'status': status,
      'joinedDate': Timestamp.fromDate(joinedDate),
      'isPrimary': isPrimary,
      'permissions': permissions,
    };
  }

  @override
  List<Object?> get props => [
        orgId,
        orgName,
        orgLogoUrl,
        role,
        status,
        joinedDate,
        isPrimary,
        permissions,
      ];
}
