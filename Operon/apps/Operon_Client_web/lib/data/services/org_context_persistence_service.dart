import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrgContextPersistenceService {
  static const String _keyOrgId = 'last_selected_org_id';
  static const String _keyOrgName = 'last_selected_org_name';
  static const String _keyOrgRole = 'last_selected_org_role';
  static const String _keyAppAccessRoleId = 'last_selected_app_access_role_id';
  static const String _keyFinancialYear = 'last_selected_financial_year';
  static const String _keyUserId = 'last_user_id'; // To verify user hasn't changed
  static const String _keyTimestamp = 'last_selected_timestamp'; // For cache invalidation

  /// Save the organization context
  static Future<void> saveContext({
    required String userId,
    required String orgId,
    required String orgName,
    required String orgRole,
    required String financialYear,
    String? appAccessRoleId,
  }) async {
    // #region agent log
    try {
      final logData = {
        "id": "log_${DateTime.now().millisecondsSinceEpoch}_save",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "location": "org_context_persistence_service.dart:saveContext",
        "message": "Saving context",
        "data": {"userId": userId, "orgId": orgId, "orgName": orgName, "financialYear": financialYear, "appAccessRoleId": appAccessRoleId},
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "A"
      };
      debugPrint('[DEBUG] ${jsonEncode(logData)}');
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (e) {
      debugPrint('[DEBUG] Log error: $e');
    }
    // #endregion
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    await Future.wait([
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyOrgId, orgId),
      prefs.setString(_keyOrgName, orgName),
      prefs.setString(_keyOrgRole, orgRole),
      if (appAccessRoleId != null) prefs.setString(_keyAppAccessRoleId, appAccessRoleId),
      prefs.setString(_keyFinancialYear, financialYear),
      prefs.setString(_keyTimestamp, timestamp),
    ]);
  }

  /// Load the saved organization context
  static Future<SavedOrgContext?> loadContext() async {
    // #region agent log
    try {
      final logData = {
        "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_start",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "location": "org_context_persistence_service.dart:loadContext",
        "message": "Loading context start",
        "data": {},
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "B"
      };
      debugPrint('[DEBUG] ${jsonEncode(logData)}');
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (e) {
      debugPrint('[DEBUG] Log error: $e');
    }
    // #endregion
    final prefs = await SharedPreferences.getInstance();
    final orgId = prefs.getString(_keyOrgId);
    final orgName = prefs.getString(_keyOrgName);
    final orgRole = prefs.getString(_keyOrgRole);
    final financialYear = prefs.getString(_keyFinancialYear);
    final userId = prefs.getString(_keyUserId);

    // #region agent log
    try {
      final logData = {
        "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_values",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "location": "org_context_persistence_service.dart:loadContext",
        "message": "Loaded values from storage",
        "data": {"orgId": orgId, "orgName": orgName, "orgRole": orgRole, "financialYear": financialYear, "userId": userId, "allPresent": orgId != null && orgName != null && orgRole != null && financialYear != null},
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "B"
      };
      debugPrint('[DEBUG] ${jsonEncode(logData)}');
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (e) {
      debugPrint('[DEBUG] Log error: $e');
    }
    // #endregion

    if (orgId == null || orgName == null || orgRole == null || financialYear == null) {
      // #region agent log
      try {
        await http.post(
          Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_null",
            "timestamp": DateTime.now().millisecondsSinceEpoch,
            "location": "org_context_persistence_service.dart:loadContext",
            "message": "Context load returned null - missing values",
            "data": {},
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": "B"
          }),
        ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
      } catch (_) {}
      // #endregion
      return null;
    }

    final timestampStr = prefs.getString(_keyTimestamp);
    final timestamp = timestampStr != null 
        ? DateTime.fromMillisecondsSinceEpoch(int.parse(timestampStr))
        : null;

    final savedContext = SavedOrgContext(
      orgId: orgId,
      orgName: orgName,
      orgRole: orgRole,
      appAccessRoleId: prefs.getString(_keyAppAccessRoleId),
      financialYear: financialYear,
      userId: prefs.getString(_keyUserId),
      timestamp: timestamp,
    );
    
    // #region agent log
    try {
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "id": "log_${DateTime.now().millisecondsSinceEpoch}_load_success",
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "location": "org_context_persistence_service.dart:loadContext",
          "message": "Context loaded successfully",
          "data": {"orgId": savedContext.orgId, "userId": savedContext.userId, "financialYear": savedContext.financialYear},
          "sessionId": "debug-session",
          "runId": "run1",
          "hypothesisId": "B"
        }),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (_) {}
    // #endregion
    
    return savedContext;
  }

  /// Clear the saved context (useful for logout)
  static Future<void> clearContext() async {
    // #region agent log
    try {
      final logData = {
        "id": "log_${DateTime.now().millisecondsSinceEpoch}_clear_context",
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "location": "org_context_persistence_service.dart:clearContext",
        "message": "Clearing context",
        "data": {"stackTrace": StackTrace.current.toString().split('\n').take(5).join(' | ')},
        "sessionId": "debug-session",
        "runId": "run1",
        "hypothesisId": "E"
      };
      debugPrint('[DEBUG] ${jsonEncode(logData)}');
      await http.post(
        Uri.parse('http://127.0.0.1:7243/ingest/0f2c904c-02d4-456a-9593-57a451fc7c6a'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(logData),
      ).timeout(const Duration(seconds: 1), onTimeout: () => throw TimeoutException('Log timeout'));
    } catch (e) {
      debugPrint('[DEBUG] Log error: $e');
    }
    // #endregion
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyUserId),
      prefs.remove(_keyOrgId),
      prefs.remove(_keyOrgName),
      prefs.remove(_keyOrgRole),
      prefs.remove(_keyAppAccessRoleId),
      prefs.remove(_keyFinancialYear),
      prefs.remove(_keyTimestamp),
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
    this.appAccessRoleId,
    this.timestamp,
  });

  final String orgId;
  final String orgName;
  final String orgRole;
  final String? appAccessRoleId; // App Access Role ID if available
  final String financialYear;
  final String? userId;
  final DateTime? timestamp; // When context was saved

  /// Check if context is recent (within 24 hours) - for cache validation
  bool get isRecent {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp!) < const Duration(hours: 24);
  }
}
