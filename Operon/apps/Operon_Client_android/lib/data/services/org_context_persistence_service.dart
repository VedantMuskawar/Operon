import 'package:shared_preferences/shared_preferences.dart';

class OrgContextPersistenceService {
  static const String _keyOrgId = 'last_selected_org_id';
  static const String _keyOrgName = 'last_selected_org_name';
  static const String _keyOrgRole = 'last_selected_org_role';
  static const String _keyFinancialYear = 'last_selected_financial_year';
  static const String _keyUserId = 'last_user_id'; // To verify user hasn't changed

  /// Save the organization context
  static Future<void> saveContext({
    required String userId,
    required String orgId,
    required String orgName,
    required String orgRole,
    required String financialYear,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyOrgId, orgId),
      prefs.setString(_keyOrgName, orgName),
      prefs.setString(_keyOrgRole, orgRole),
      prefs.setString(_keyFinancialYear, financialYear),
    ]);
  }

  /// Load the saved organization context
  static Future<SavedOrgContext?> loadContext() async {
    final prefs = await SharedPreferences.getInstance();
    final orgId = prefs.getString(_keyOrgId);
    final orgName = prefs.getString(_keyOrgName);
    final orgRole = prefs.getString(_keyOrgRole);
    final financialYear = prefs.getString(_keyFinancialYear);

    if (orgId == null || orgName == null || orgRole == null || financialYear == null) {
      return null;
    }

    return SavedOrgContext(
      orgId: orgId,
      orgName: orgName,
      orgRole: orgRole,
      financialYear: financialYear,
      userId: prefs.getString(_keyUserId),
    );
  }

  /// Clear the saved context (useful for logout)
  static Future<void> clearContext() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyUserId),
      prefs.remove(_keyOrgId),
      prefs.remove(_keyOrgName),
      prefs.remove(_keyOrgRole),
      prefs.remove(_keyFinancialYear),
    ]);
  }

  /// Check if saved context exists for a specific user
  static Future<bool> hasContextForUser(String userId) async {
    final context = await loadContext();
    return context != null && context.userId == userId;
  }
}

class SavedOrgContext {
  const SavedOrgContext({
    required this.orgId,
    required this.orgName,
    required this.orgRole,
    required this.financialYear,
    this.userId,
  });

  final String orgId;
  final String orgName;
  final String orgRole;
  final String financialYear;
  final String? userId;
}

