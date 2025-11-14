/// Utilities for computing the Indian financial year (April 1 - March 31).
class FinancialYearUtils {
  /// Returns an identifier like `2024-2025` for the financial year that
  /// contains [date].
  static String financialYearId([DateTime? date]) {
    final anchor = date ?? DateTime.now();
    final startYear = anchor.month >= DateTime.april
        ? anchor.year
        : anchor.year - 1;
    final endYear = startYear + 1;
    return '$startYear-$endYear';
  }

  /// Returns the inclusive start of the financial year containing [date].
  static DateTime startOfFinancialYear([DateTime? date]) {
    final anchor = date ?? DateTime.now();
    final startYear = anchor.month >= DateTime.april
        ? anchor.year
        : anchor.year - 1;
    return DateTime(startYear, DateTime.april, 1);
  }

  /// Returns the inclusive end of the financial year containing [date].
  static DateTime endOfFinancialYear([DateTime? date]) {
    final start = startOfFinancialYear(date);
    return DateTime(start.year + 1, DateTime.march, 31, 23, 59, 59, 999);
  }
}


