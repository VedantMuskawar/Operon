import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:dash_web/data/repositories/employees_repository.dart';
import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'weekly_ledger_state.dart';

class WeeklyLedgerCubit extends Cubit<WeeklyLedgerState> {
  WeeklyLedgerCubit({
    required ProductionBatchesRepository productionBatchesRepository,
    required TripWagesRepository tripWagesRepository,
    required EmployeesRepository employeesRepository,
    required DeliveryMemoRepository deliveryMemoRepository,
    required EmployeeWagesRepository employeeWagesRepository,
    required String organizationId,
  })  : _productionBatchesRepository = productionBatchesRepository,
        _tripWagesRepository = tripWagesRepository,
        _employeesRepository = employeesRepository,
        _deliveryMemoRepository = deliveryMemoRepository,
        _employeeWagesRepository = employeeWagesRepository,
        _organizationId = organizationId,
        super(const WeeklyLedgerState());

  final ProductionBatchesRepository _productionBatchesRepository;
  final TripWagesRepository _tripWagesRepository;
  final EmployeesRepository _employeesRepository;
  final DeliveryMemoRepository _deliveryMemoRepository;
  final EmployeeWagesRepository _employeeWagesRepository;
  final String _organizationId;

  /// Returns Monday 00:00:00 of the week containing [date].
  static DateTime weekStart(DateTime date) {
    final weekday = date.weekday;
    final daysFromMonday = weekday == 7 ? 0 : weekday - 1;
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: daysFromMonday));
  }

  /// Returns Sunday 23:59:59 of the week containing [date].
  static DateTime weekEnd(DateTime date) {
    final start = weekStart(date);
    return DateTime(start.year, start.month, start.day, 23, 59, 59)
        .add(const Duration(days: 6));
  }

  /// Calculate financial year label from a date
  /// Financial year starts in April (month 4)
  /// Format: FY2425 (for April 2024 - March 2025)
  String _getFinancialYear(DateTime date) {
    final year = date.year;
    final month = date.month;
    // Financial year starts in April (month 4)
    if (month >= 4) {
      final startYear = year % 100;
      final endYear = (year + 1) % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    } else {
      final startYear = (year - 1) % 100;
      final endYear = year % 100;
      return 'FY${startYear.toString().padLeft(2, '0')}${endYear.toString().padLeft(2, '0')}';
    }
  }

  /// Get year-month string in format YYYYMM for document IDs
  /// Format: "202401" for January 2024
  String _getYearMonth(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}';
  }

  /// Get all unique yearMonths for a date range
  List<String> _getYearMonths(DateTime start, DateTime end) {
    final yearMonths = <String>{};
    var current = DateTime(start.year, start.month, 1);
    final endMonth = DateTime(end.year, end.month, 1);

    while (current.isBefore(endMonth) || current.isAtSameMomentAs(endMonth)) {
      yearMonths.add(_getYearMonth(current));
      current = DateTime(current.year, current.month + 1, 1);
    }

    return yearMonths.toList();
  }

  /// Load weekly ledger data for the given week (Monday–Sunday).
  Future<void> loadWeeklyLedger(DateTime weekStartDate, DateTime weekEndDate) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final start = DateTime(weekStartDate.year, weekStartDate.month, weekStartDate.day);
      final end = DateTime(weekEndDate.year, weekEndDate.month, weekEndDate.day, 23, 59, 59);

      // Fetch all employees
      final allEmployees = await _employeesRepository.fetchEmployees(_organizationId);
      final productionEmployees = _filterProductionEmployees(allEmployees);
      final employeeMap = {for (var e in allEmployees) e.id: e};

      // Fetch batches and trip wages for the week
      final batches = await _productionBatchesRepository.fetchProductionBatches(
        _organizationId,
        startDate: start,
        endDate: end,
      );
      final tripWages = await _tripWagesRepository.fetchTripWages(
        _organizationId,
        startDate: start,
        endDate: end,
      );

      // Build entries
      final productionEntries = await _buildProductionEntries(
        batches,
        productionEmployees,
        employeeMap,
        start,
        end,
      );
      final tripEntries = await _buildTripEntries(
        tripWages,
        productionEmployees,
        employeeMap,
        start,
        end,
      );

      emit(state.copyWith(
        status: ViewStatus.success,
        weekStart: start,
        weekEnd: end,
        productionEntries: productionEntries,
        tripEntries: tripEntries,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[WeeklyLedgerCubit] Error loading weekly ledger: $e');
      debugPrint('[WeeklyLedgerCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load weekly ledger: ${e.toString()}',
      ));
    }
  }

  List<OrganizationEmployee> _filterProductionEmployees(List<OrganizationEmployee> employees) {
    return employees.where((employee) {
      return employee.jobRoles.values.any(
            (jobRole) =>
                jobRole.jobRoleTitle.toLowerCase().contains('production'),
          ) ||
          employee.primaryJobRoleTitle.toLowerCase().contains('production');
    }).toList();
  }

  Future<List<ProductionLedgerEntry>> _buildProductionEntries(
    List<ProductionBatch> batches,
    List<OrganizationEmployee> productionEmployees,
    Map<String, OrganizationEmployee> employeeMap,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    final entries = <ProductionLedgerEntry>[];
    
    // Get unique yearMonths for the week
    final yearMonths = _getYearMonths(weekStart, weekEnd);
    final financialYear = _getFinancialYear(weekStart);

    for (final batch in batches) {
      // Get employees in this batch that have Production tag
      final batchEmployeeIds = batch.employeeIds.toSet();
      final productionEmployeeIds = productionEmployees.map((e) => e.id).toSet();
      final relevantEmployeeIds = batchEmployeeIds.intersection(productionEmployeeIds).toList();

      if (relevantEmployeeIds.isEmpty) {
        continue; // Skip batches with no production employees
      }

      final names = <String>[];
      final balances = <double>[];
      
      for (final id in relevantEmployeeIds) {
        final employee = employeeMap[id];
        if (employee != null) {
          names.add(employee.name);
          balances.add(employee.currentBalance);
        }
      }

      // Fetch wage transactions for all production employees in this batch
      final allTransactions = <Map<String, dynamic>>[];
      for (final employeeId in relevantEmployeeIds) {
        for (final yearMonth in yearMonths) {
          final monthlyTransactions = await _employeeWagesRepository.fetchMonthlyTransactions(
            employeeId: employeeId,
            financialYear: financialYear,
            yearMonth: yearMonth,
          );
          
          // Filter transactions by batchId and category
          final batchTransactions = monthlyTransactions.where((tx) {
            final category = tx['category'] as String?;
            final metadata = tx['metadata'] as Map<String, dynamic>?;
            final batchId = metadata?['batchId'] as String?;
            
            return category == 'wageCredit' &&
                metadata?['sourceType'] == 'productionBatch' &&
                batchId == batch.batchId;
          }).toList();
          
          allTransactions.addAll(batchTransactions);
        }
      }

      // Convert to WeeklyLedgerTransactionRow
      final salaryTransactions = allTransactions.map((tx) {
        final description = tx['description'] as String? ?? 'Wage credit';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final transactionId = tx['transactionId'] as String?;
        return WeeklyLedgerTransactionRow(
          transactionId: transactionId,
          description: description,
          amount: amount,
        );
      }).toList();

      entries.add(ProductionLedgerEntry(
        date: batch.batchDate,
        batchNo: batch.batchId,
        batchId: batch.batchId,
        employeeNames: names,
        employeeBalances: balances,
        salaryTransactions: salaryTransactions,
      ));
    }
    
    entries.sort((a, b) => b.date.compareTo(a.date));
    return entries;
  }

  Future<List<TripLedgerEntry>> _buildTripEntries(
    List<TripWage> tripWages,
    List<OrganizationEmployee> productionEmployees,
    Map<String, OrganizationEmployee> employeeMap,
    DateTime weekStart,
    DateTime weekEnd,
  ) async {
    // Group trip wages by date + vehicle
    final grouped = <String, List<TripWage>>{};
    
    for (final tw in tripWages) {
      final dm = await _deliveryMemoRepository.getDeliveryMemo(tw.dmId);
      final vehicleNo = dm?['vehicleNumber'] as String? ?? 'N/A';
      final date = tw.createdAt;
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final key = '$dateKey|$vehicleNo';
      grouped.putIfAbsent(key, () => []).add(tw);
    }

    final entries = <TripLedgerEntry>[];
    
    // Get unique yearMonths for the week
    final yearMonths = _getYearMonths(weekStart, weekEnd);
    final financialYear = _getFinancialYear(weekStart);

    for (final entry in grouped.entries) {
      final parts = entry.key.split('|');
      final vehicleNo = parts[1];
      final twList = entry.value;
      final date = twList.first.createdAt;

      // Get all unique employee IDs from loading and unloading
      final allEmployeeIds = <String>{};
      for (final tw in twList) {
        allEmployeeIds.addAll(tw.loadingEmployeeIds);
        allEmployeeIds.addAll(tw.unloadingEmployeeIds);
      }

      // Filter to only production employees
      final productionEmployeeIds = productionEmployees.map((e) => e.id).toSet();
      final relevantEmployeeIds = allEmployeeIds.intersection(productionEmployeeIds).toList();

      if (relevantEmployeeIds.isEmpty) {
        continue; // Skip trips with no production employees
      }

      final names = <String>[];
      final balances = <double>[];
      
      for (final id in relevantEmployeeIds) {
        final employee = employeeMap[id];
        if (employee != null) {
          names.add(employee.name);
          balances.add(employee.currentBalance);
        }
      }

      // Fetch wage transactions for all production employees in these trip wages
      final allTransactions = <Map<String, dynamic>>[];
      final tripWageIds = twList.map((tw) => tw.tripWageId).toSet();
      
      for (final employeeId in relevantEmployeeIds) {
        for (final yearMonth in yearMonths) {
          final monthlyTransactions = await _employeeWagesRepository.fetchMonthlyTransactions(
            employeeId: employeeId,
            financialYear: financialYear,
            yearMonth: yearMonth,
          );
          
          // Filter transactions by tripWageId and category
          final tripTransactions = monthlyTransactions.where((tx) {
            final category = tx['category'] as String?;
            final metadata = tx['metadata'] as Map<String, dynamic>?;
            final tripWageId = metadata?['tripWageId'] as String?;
            
            return category == 'wageCredit' &&
                metadata?['sourceType'] == 'tripWage' &&
                tripWageId != null &&
                tripWageIds.contains(tripWageId);
          }).toList();
          
          allTransactions.addAll(tripTransactions);
        }
      }

      // Convert to WeeklyLedgerTransactionRow
      final salaryTransactions = allTransactions.map((tx) {
        final description = tx['description'] as String? ?? 'Wage credit';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final transactionId = tx['transactionId'] as String?;
        return WeeklyLedgerTransactionRow(
          transactionId: transactionId,
          description: description,
          amount: amount,
        );
      }).toList();

      entries.add(TripLedgerEntry(
        date: date,
        vehicleNo: vehicleNo,
        tripCount: twList.length,
        employeeNames: names,
        employeeBalances: balances,
        salaryTransactions: salaryTransactions,
      ));
    }
    
    entries.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      return a.vehicleNo.compareTo(b.vehicleNo);
    });
    
    return entries;
  }
}
