import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SuperAdminConfig extends Equatable {
  final String defaultSubscriptionTier;
  final int defaultUserLimit;
  final int maxOrganizations;
  final bool maintenanceMode;
  final List<String> allowedDomains;
  final Map<String, dynamic> notificationSettings;
  final Map<String, dynamic> securitySettings;
  final DateTime lastUpdated;

  const SuperAdminConfig({
    required this.defaultSubscriptionTier,
    required this.defaultUserLimit,
    required this.maxOrganizations,
    required this.maintenanceMode,
    required this.allowedDomains,
    required this.notificationSettings,
    required this.securitySettings,
    required this.lastUpdated,
  });

  factory SuperAdminConfig.fromMap(Map<String, dynamic> map) {
    return SuperAdminConfig(
      defaultSubscriptionTier: map['defaultSubscriptionTier'] ?? 'basic',
      defaultUserLimit: map['defaultUserLimit'] ?? 10,
      maxOrganizations: map['maxOrganizations'] ?? 100,
      maintenanceMode: map['maintenanceMode'] ?? false,
      allowedDomains: List<String>.from(map['allowedDomains'] ?? []),
      notificationSettings: Map<String, dynamic>.from(map['notificationSettings'] ?? {}),
      securitySettings: Map<String, dynamic>.from(map['securitySettings'] ?? {}),
      lastUpdated: (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultSubscriptionTier': defaultSubscriptionTier,
      'defaultUserLimit': defaultUserLimit,
      'maxOrganizations': maxOrganizations,
      'maintenanceMode': maintenanceMode,
      'allowedDomains': allowedDomains,
      'notificationSettings': notificationSettings,
      'securitySettings': securitySettings,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  SuperAdminConfig copyWith({
    String? defaultSubscriptionTier,
    int? defaultUserLimit,
    int? maxOrganizations,
    bool? maintenanceMode,
    List<String>? allowedDomains,
    Map<String, dynamic>? notificationSettings,
    Map<String, dynamic>? securitySettings,
    DateTime? lastUpdated,
  }) {
    return SuperAdminConfig(
      defaultSubscriptionTier: defaultSubscriptionTier ?? this.defaultSubscriptionTier,
      defaultUserLimit: defaultUserLimit ?? this.defaultUserLimit,
      maxOrganizations: maxOrganizations ?? this.maxOrganizations,
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      allowedDomains: allowedDomains ?? this.allowedDomains,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      securitySettings: securitySettings ?? this.securitySettings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        defaultSubscriptionTier,
        defaultUserLimit,
        maxOrganizations,
        maintenanceMode,
        allowedDomains,
        notificationSettings,
        securitySettings,
        lastUpdated,
      ];
}

// Default configuration
class DefaultSuperAdminConfig {
  static SuperAdminConfig get config => SuperAdminConfig(
        defaultSubscriptionTier: 'basic',
        defaultUserLimit: 10,
        maxOrganizations: 100,
        maintenanceMode: false,
        allowedDomains: ['gmail.com', 'outlook.com', 'yahoo.com'],
        notificationSettings: {
          'emailNotifications': true,
          'pushNotifications': true,
          'smsNotifications': false,
          'maintenanceAlerts': true,
        },
        securitySettings: {
          'requireStrongPasswords': true,
          'sessionTimeoutMinutes': 60,
          'maxLoginAttempts': 5,
          'twoFactorAuth': false,
        },
        lastUpdated: DateTime.now(),
      );
}
