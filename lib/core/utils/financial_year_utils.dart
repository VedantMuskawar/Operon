/// Utilities for working with financial years based on the Indian fiscal cycle
/// (April 1 to March 31).
class FinancialYearUtils {
  /// Returns the financial year identifier for the provided [date].
  ///
  /// The identifier is formatted as `YYYY-YYYY`, where the first segment is the
  /// fiscal start year (April 1) and the second segment is the fiscal end year
  /// (March 31).
  static String financialYearId([DateTime? date]) {
    final anchor = date ?? DateTime.now();
    final startYear = anchor.month >= DateTime.april
        ? anchor.year
        : anchor.year - 1;
    final endYear = startYear + 1;
    return '$startYear-$endYear';
  }

  /// Returns the start date (inclusive) of the financial year containing [date].
  static DateTime startOfFinancialYear([DateTime? date]) {
    final anchor = date ?? DateTime.now();
    final startYear = anchor.month >= DateTime.april
        ? anchor.year
        : anchor.year - 1;
    return DateTime(startYear, DateTime.april, 1);
  }

  /// Returns the end date (inclusive) of the financial year containing [date].
  static DateTime endOfFinancialYear([DateTime? date]) {
    final start = startOfFinancialYear(date);
    return DateTime(start.year + 1, DateTime.march, 31, 23, 59, 59, 999);
  }
}


