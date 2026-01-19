import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RecentlyViewedEmployeesService {
  static const String _keyPrefix = 'recently_viewed_employees_';
  static const int _maxRecentItems = 10;

  /// Get the storage key for a specific organization
  static String _getStorageKey(String organizationId) {
    return '$_keyPrefix$organizationId';
  }

  /// Track an employee as recently viewed
  /// Adds the employee ID to the beginning of the list and removes duplicates
  static Future<void> trackEmployeeView({
    required String organizationId,
    required String employeeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey(organizationId);
    
    // Get current list
    final currentList = await getRecentlyViewedIds(organizationId);
    
    // Remove employeeId if it exists (to avoid duplicates)
    currentList.remove(employeeId);
    
    // Add to beginning
    currentList.insert(0, employeeId);
    
    // Keep only the most recent items
    final trimmedList = currentList.take(_maxRecentItems).toList();
    
    // Save back to storage
    await prefs.setString(key, jsonEncode(trimmedList));
  }

  /// Get list of recently viewed employee IDs (most recent first)
  static Future<List<String>> getRecentlyViewedIds(String organizationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey(organizationId);
    final jsonString = prefs.getString(key);
    
    if (jsonString == null) {
      return [];
    }
    
    try {
      final decoded = jsonDecode(jsonString) as List;
      return decoded.cast<String>();
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  /// Clear recently viewed employees for an organization
  static Future<void> clearRecentlyViewed(String organizationId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getStorageKey(organizationId);
    await prefs.remove(key);
  }

  /// Get recently viewed employees from full employee list (ordered by most recent first)
  static List<T> getRecentlyViewedEmployees<T>({
    required List<T> allEmployees,
    required List<String> recentlyViewedIds,
    required String Function(T) getId,
  }) {
    // Create a map for quick lookup
    final employeeMap = <String, T>{};
    for (final employee in allEmployees) {
      employeeMap[getId(employee)] = employee;
    }
    
    // Build list in order of recently viewed IDs, filtering out employees that no longer exist
    final result = <T>[];
    for (final id in recentlyViewedIds) {
      final employee = employeeMap[id];
      if (employee != null) {
        result.add(employee);
      }
    }
    
    return result;
  }
}
