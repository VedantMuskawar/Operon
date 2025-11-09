class AppConstants {
  // Super Admin Configuration
  static const String superAdminPhoneNumber = '+919876543210'; // Test Super Admin phone number
  
  // User Roles
  static const int superAdminRole = 0;
  static const int adminRole = 1;
  static const int managerRole = 2;
  static const int driverRole = 3;

  static const Map<int, String> roleNames = {
    superAdminRole: 'Super Admin',
    adminRole: 'Admin',
    managerRole: 'Manager',
    driverRole: 'Driver',
  };

  // Organization Status
  static const String orgStatusActive = 'active';
  static const String orgStatusInactive = 'inactive';
  static const String orgStatusSuspended = 'suspended';

  // User Status
  static const String userStatusActive = 'active';
  static const String userStatusInactive = 'inactive';
  static const String userStatusInvited = 'invited';
  static const String userStatusPending = 'pending';
  static const String userStatusSuspended = 'suspended';

  // Subscription Tiers
  static const String subscriptionTierBasic = 'basic';
  static const String subscriptionTierPremium = 'premium';
  static const String subscriptionTierEnterprise = 'enterprise';

  // Subscription Types
  static const String subscriptionTypeMonthly = 'monthly';
  static const String subscriptionTypeYearly = 'yearly';

  // Subscription Status
  static const String subscriptionStatusActive = 'active';
  static const String subscriptionStatusExpired = 'expired';
  static const String subscriptionStatusCancelled = 'cancelled';

  // Firestore Collections (CAPITAL LETTERS)
  static const String organizationsCollection = 'ORGANIZATIONS';
  static const String usersCollection = 'USERS';
  static const String employeesCollection = 'EMPLOYEES';
  static const String superadminConfigCollection = 'SUPERADMIN_CONFIG';
  static const String systemMetadataCollection = 'SYSTEM_METADATA';

  // Firestore Subcollections (CAPITAL LETTERS)
  static const String subscriptionSubcollection = 'SUBSCRIPTION';
  static const String usersSubcollection = 'USERS';
  static const String organizationsSubcollection = 'ORGANIZATIONS';
  static const String rolesSubcollection = 'ROLES';
  static const String employeeLedgerSubcollection = 'LEDGER';
  static const String activitySubcollection = 'ACTIVITY';

  // Employee Status
  static const String employeeStatusActive = 'active';
  static const String employeeStatusInactive = 'inactive';
  static const String employeeStatusInvited = 'invited';

  // Employee Wage Types
  static const String employeeWageTypeHourly = 'hourly';
  static const String employeeWageTypeQuantity = 'quantity';
  static const String employeeWageTypeMonthly = 'monthly';

  // Employee Compensation Frequency
  static const String employeeCompFrequencyMonthly = 'monthly';
  static const String employeeCompFrequencyBiweekly = 'biweekly';
  static const String employeeCompFrequencyWeekly = 'weekly';
  static const String employeeCompFrequencyPerShift = 'per_shift';

  // Storage Paths - Organized Folder Structure
  // Organizations
  static const String organizationsPath = 'organizations';
  static const String orgLogosPath = '$organizationsPath/{orgId}/logos';
  static const String orgDocumentsPath = '$organizationsPath/{orgId}/documents';
  static const String orgAttachmentsPath = '$organizationsPath/{orgId}/attachments';
  
  // Users
  static const String usersStoragePath = 'users';
  static const String userProfilePhotosPath = '$usersStoragePath/{userId}/profile_photos';
  static const String userDocumentsPath = '$usersStoragePath/{userId}/documents';
  static const String userAttachmentsPath = '$usersStoragePath/{userId}/attachments';
  
  // System
  static const String systemPath = 'system';
  static const String systemTemplatesPath = '$systemPath/templates';
  static const String systemAssetsPath = '$systemPath/assets';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;

  // Default Values
  static const int defaultUserLimit = 10;
  static const String defaultCurrency = 'INR';
  static const String defaultIndustry = 'Technology';
  static const String defaultLocation = 'India';

  // Activity Types
  static const String activityTypeUserAdded = 'user_added';
  static const String activityTypeUserRemoved = 'user_removed';
  static const String activityTypeUserUpdated = 'user_updated';
  static const String activityTypeSubscriptionUpdated = 'subscription_updated';
  static const String activityTypeOrgUpdated = 'org_updated';
  static const String activityTypeOrgCreated = 'org_created';

  // Notification Types
  static const String notificationTypeSubscriptionExpiring = 'subscription_expiring';
  static const String notificationTypeUserInvited = 'user_invited';
  static const String notificationTypeOrgSuspended = 'org_suspended';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork = 'Network error. Please check your connection.';
  static const String errorUnauthorized = 'You are not authorized to perform this action.';
  static const String errorNotFound = 'The requested resource was not found.';
  static const String errorValidation = 'Please check your input and try again.';

  // Success Messages
  static const String successOrganizationCreated = 'Organization created successfully!';
  static const String successOrganizationUpdated = 'Organization updated successfully!';
  static const String successUserAdded = 'User added successfully!';
  static const String successUserUpdated = 'User updated successfully!';
  static const String successSubscriptionUpdated = 'Subscription updated successfully!';

  // App Info
  static const String appName = 'OPERON';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Organization Management System';
}



