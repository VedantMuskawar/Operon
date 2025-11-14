import 'package:flutter_test/flutter_test.dart';
import 'package:operon/core/utils/financial_year_utils.dart';

void main() {
  group('FinancialYearUtils', () {
    test('financialYearId uses previous year for dates before April', () {
      final marchDate = DateTime(2025, DateTime.march, 31);
      expect(
        FinancialYearUtils.financialYearId(marchDate),
        equals('2024-2025'),
      );
    });

    test('financialYearId advances on or after April 1', () {
      final aprilDate = DateTime(2025, DateTime.april, 1);
      expect(
        FinancialYearUtils.financialYearId(aprilDate),
        equals('2025-2026'),
      );
    });

    test('startOfFinancialYear returns April 1 of fiscal start year', () {
      final date = DateTime(2024, DateTime.december, 15);
      final start = FinancialYearUtils.startOfFinancialYear(date);
      expect(start.year, equals(2024));
      expect(start.month, equals(DateTime.april));
      expect(start.day, equals(1));
    });

    test('endOfFinancialYear returns March 31 23:59:59.999 of fiscal end year',
        () {
      final date = DateTime(2024, DateTime.january, 10);
      final end = FinancialYearUtils.endOfFinancialYear(date);
      expect(end.year, equals(2024));
      expect(end.month, equals(DateTime.march));
      expect(end.day, equals(31));
      expect(end.hour, equals(23));
      expect(end.minute, equals(59));
      expect(end.second, equals(59));
      expect(end.millisecond, equals(999));
    });
  });
}


