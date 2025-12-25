/// Utility functions for financial year and ISO week calculations
library;

class FinancialYearUtils {
  /// Calculate financial year label from a date
  /// Financial year starts in April (month 4)
  /// Format: FY2425 (for April 2024 - March 2025)
  static String getFinancialYear(DateTime date) {
    final fyStartYear = date.month >= 4 ? date.year : date.year - 1;
    final first = (fyStartYear % 100).toString().padLeft(2, '0');
    final second = ((fyStartYear + 1) % 100).toString().padLeft(2, '0');
    return 'FY$first$second';
  }

  /// Get financial year for current date
  static String getCurrentFinancialYear() {
    return getFinancialYear(DateTime.now());
  }

  /// Get ISO week number for a date
  /// ISO week starts on Monday and week 1 is the first week with at least 4 days in the new year
  /// Returns format: YYYY-Www (e.g., "2024-W14")
  static String getISOWeek(DateTime date) {
    // Create a copy to avoid modifying the original
    final d = DateTime(date.year, date.month, date.day);
    
    // Find the Thursday of the week (ISO week starts on Monday)
    // Thursday is always in the ISO week's year
    final thursday = d.add(Duration(days: 4 - (d.weekday % 7 == 0 ? 7 : d.weekday)));
    
    // January 4th is always in week 1
    final jan4 = DateTime(thursday.year, 1, 4);
    final jan4Thursday = jan4.add(Duration(days: 4 - (jan4.weekday % 7 == 0 ? 7 : jan4.weekday)));
    
    // Calculate week number
    final daysDiff = thursday.difference(jan4Thursday).inDays;
    final weekNumber = ((daysDiff / 7).floor() + 1);
    
    return '${thursday.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }

  /// Get ISO week for current date
  static String getCurrentISOWeek() {
    return getISOWeek(DateTime.now());
  }

  /// Format date as YYYY-MM-DD
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Format date as YYYY-MM (for monthly breakdown)
  static String formatMonth(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  /// Get date string for today
  static String getTodayDateString() {
    return formatDate(DateTime.now());
  }

  /// Get month string for today
  static String getCurrentMonthString() {
    return formatMonth(DateTime.now());
  }

  /// Check if a date is within the last N days
  static bool isWithinLastDays(DateTime date, int days) {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));
    return date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate);
  }

  /// Clean up daily data older than specified days
  /// Returns a map with only entries from the last N days
  static Map<String, dynamic> cleanDailyData(
    Map<String, dynamic> dailyData,
    int keepDays,
  ) {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    final cleaned = <String, dynamic>{};
    
    dailyData.forEach((dateString, value) {
      try {
        final parts = dateString.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
          if (date.isAfter(cutoffDate) || date.isAtSameMomentAs(cutoffDate)) {
            cleaned[dateString] = value;
          }
        }
      } catch (e) {
        // Skip invalid date strings
      }
    });
    
    return cleaned;
  }
}

