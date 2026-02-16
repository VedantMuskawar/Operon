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
  List<OrganizationEmployee>? _employeesCache;

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
      debugPrint('[WeeklyLedgerCubit] loadWeeklyLedger start=${start.toIso8601String()} end=${end.toIso8601String()}');

      // Fetch all employees
      final allEmployees = _employeesCache ??
          await _employeesRepository.fetchEmployees(_organizationId);
      _employeesCache ??= allEmployees;
      final productionEmployees = _filterProductionEmployees(allEmployees);
      if (productionEmployees.isEmpty) {
        debugPrint('[WeeklyLedgerCubit] No production-tagged employees found; using all employees.');
      }
      debugPrint('[WeeklyLedgerCubit] employees total=${allEmployees.length} productionRelevant=${productionEmployees.length}');
      final employeeMap = {for (var e in allEmployees) e.id: e};

      final monthlyTransactionsCache = <String, List<Map<String, dynamic>>>{};
      final deliveryMemoCache = <String, String>{};

      // Fetch batches and trip wages for the week
      final batches = await _productionBatchesRepository.fetchProductionBatches(
        _organizationId,
        startDate: start,
        endDate: end,
      );
      debugPrint('[WeeklyLedgerCubit] batches fetched=${batches.length}');
      final tripWages = await _tripWagesRepository.fetchTripWages(
        _organizationId,
        startDate: start,
        endDate: end,
      );
      debugPrint('[WeeklyLedgerCubit] tripWages fetched=${tripWages.length}');

      // Build entries
      final productionEntries = await _buildProductionEntries(
        batches,
        employeeMap,
        start,
        end,
        monthlyTransactionsCache,
      );
      debugPrint('[WeeklyLedgerCubit] productionEntries built=${productionEntries.length}');
      final tripEntries = await _buildTripEntries(
        tripWages,
        employeeMap,
        start,
        end,
        monthlyTransactionsCache,
        deliveryMemoCache,
      );
      debugPrint('[WeeklyLedgerCubit] tripEntries built=${tripEntries.length}');

      final hasAnyData = productionEntries.isNotEmpty || tripEntries.isNotEmpty;

      final employeeIds = <String>{};
      for (final entry in productionEntries) {
        employeeIds.addAll(entry.employeeIds);
      }
      for (final entry in tripEntries) {
        employeeIds.addAll(entry.employeeIds);
      }

      final debitByEmployeeId = await _computeDebitsByEmployee(
        employeeIds: employeeIds,
        start: start,
        end: end,
        monthlyTransactionsCache: monthlyTransactionsCache,
      );

      final currentBalanceByEmployeeId = <String, double>{};
      for (final id in employeeIds) {
        final employee = employeeMap[id];
        if (employee != null) {
          currentBalanceByEmployeeId[id] = employee.currentBalance;
        }
      }
      debugPrint('[WeeklyLedgerCubit] hasAnyData=$hasAnyData');

      emit(state.copyWith(
        status: ViewStatus.success,
        weekStart: start,
        weekEnd: end,
        productionEntries: productionEntries,
        tripEntries: tripEntries,
        debitByEmployeeId: debitByEmployeeId,
        currentBalanceByEmployeeId: currentBalanceByEmployeeId,
        message: hasAnyData ? null : 'No ledger data for the selected week.',
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
    Map<String, OrganizationEmployee> employeeMap,
    DateTime weekStart,
    DateTime weekEnd,
    Map<String, List<Map<String, dynamic>>> monthlyTransactionsCache,
  ) async {
    final entries = <ProductionLedgerEntry>[];
    var skippedBatches = 0;
    
    // Get unique yearMonths for the week
    final yearMonths = _getYearMonths(weekStart, weekEnd);
    final financialYear = _getFinancialYear(weekStart);

    for (final batch in batches) {
      // Get employees in this batch (no role filtering)
      final batchEmployeeIds = batch.employeeIds.toSet();
      final relevantEmployeeIds = batchEmployeeIds.toList();

      if (relevantEmployeeIds.isEmpty) {
        skippedBatches++;
        continue; // Skip batches with no production employees
      }

      final names = <String>[];
      final balances = <double>[];
      
      final resolvedEmployeeIds = <String>[];
      for (final id in relevantEmployeeIds) {
        final employee = employeeMap[id];
        if (employee != null) {
          resolvedEmployeeIds.add(id);
          names.add(employee.name);
          balances.add(employee.currentBalance);
        }
      }

      if (resolvedEmployeeIds.isEmpty) {
        skippedBatches++;
        continue;
      }

      // Fetch wage transactions for all production employees in this batch (parallel reads)
      final allTransactions = <Map<String, dynamic>>[];
      
      // Build futures for all employee/yearMonth combinations
      final futures = <Future<List<Map<String, dynamic>>>>[]; 
      final futuresMeta = <({String employeeId, String yearMonth})>[];
      
      for (final employeeId in resolvedEmployeeIds) {
        for (final yearMonth in yearMonths) {
          futures.add(
            _getMonthlyTransactionsCached(
              cache: monthlyTransactionsCache,
              employeeId: employeeId,
              financialYear: financialYear,
              yearMonth: yearMonth,
            ),
          );
          futuresMeta.add((employeeId: employeeId, yearMonth: yearMonth));
        }
      }
      
      // Fetch all in parallel
      final results = await Future.wait(futures);
      
      // Process results
      for (int i = 0; i < results.length; i++) {
        final monthlyTransactions = results[i];
        final employeeId = futuresMeta[i].employeeId;
        
        // Filter transactions by batchId and category
        final batchTransactions = monthlyTransactions.where((tx) {
          final category = tx['category'] as String?;
          final metadata = tx['metadata'] as Map<String, dynamic>?;
          final batchId = metadata?['batchId'] as String?;
          
          return category == 'wageCredit' &&
              metadata?['sourceType'] == 'productionBatch' &&
              batchId == batch.batchId;
        }).toList();
        
        allTransactions.addAll(
          batchTransactions.map((tx) => {
            ...tx,
            '_employeeId': employeeId,
          }),
        );
      }

      // Convert to WeeklyLedgerTransactionRow
      final salaryTransactions = <WeeklyLedgerTransactionRow>[];
      for (final employeeId in resolvedEmployeeIds) {
        final employeeTransactions = allTransactions.where((tx) {
          return (tx['_employeeId'] as String?) == employeeId;
        });
        for (final tx in employeeTransactions) {
          final description = tx['description'] as String? ?? 'Wage credit';
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final transactionId = tx['transactionId'] as String?;
          salaryTransactions.add(WeeklyLedgerTransactionRow(
            transactionId: transactionId,
            description: description,
            amount: amount,
            employeeId: employeeId,
          ));
        }
      }

      entries.add(ProductionLedgerEntry(
        date: batch.batchDate,
        batchNo: batch.batchId,
        batchId: batch.batchId,
        bricksProduced: batch.totalBricksProduced,
        bricksStacked: batch.totalBricksStacked,
        employeeIds: resolvedEmployeeIds,
        employeeNames: names,
        employeeBalances: balances,
        salaryTransactions: salaryTransactions,
      ));
    }
    
    entries.sort((a, b) => b.date.compareTo(a.date));
    debugPrint('[WeeklyLedgerCubit] productionEntries: totalBatches=${batches.length} skipped=$skippedBatches entries=${entries.length}');
    return entries;
  }

  Future<List<TripLedgerEntry>> _buildTripEntries(
    List<TripWage> tripWages,
    Map<String, OrganizationEmployee> employeeMap,
    DateTime weekStart,
    DateTime weekEnd,
    Map<String, List<Map<String, dynamic>>> monthlyTransactionsCache,
    Map<String, String> deliveryMemoCache,
  ) async {
    // Group trip wages by date + vehicle
    final grouped = <String, List<TripWage>>{};
    
    for (final tw in tripWages) {
      String vehicleNo = 'N/A';

      final cachedVehicle = deliveryMemoCache[tw.dmId];
      if (cachedVehicle != null) {
        vehicleNo = cachedVehicle;
      } else {
        // Try to fetch delivery memo, but don't fail if it's not accessible
        try {
          final dm = await _deliveryMemoRepository.getDeliveryMemo(tw.dmId);
          vehicleNo = dm?['vehicleNumber'] as String? ?? 'N/A';
        } catch (e) {
          // Log the error but continue - use default vehicle number
          debugPrint('[WeeklyLedgerCubit] Warning: Could not fetch delivery memo ${tw.dmId}: $e');
          vehicleNo = 'N/A';
        }
        deliveryMemoCache[tw.dmId] = vehicleNo;
      }
      
      final date = tw.createdAt;
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final key = '$dateKey|$vehicleNo';
      grouped.putIfAbsent(key, () => []).add(tw);
    }

    final entries = <TripLedgerEntry>[];
    
    // Get unique yearMonths for the week
    final yearMonths = _getYearMonths(weekStart, weekEnd);
    final financialYear = _getFinancialYear(weekStart);

    var skippedGroups = 0;
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

      // Use all employees referenced in the trip wages (no role filtering)
      final relevantEmployeeIds = allEmployeeIds.toList();

      if (relevantEmployeeIds.isEmpty) {
        skippedGroups++;
        continue; // Skip trips with no production employees
      }

      final names = <String>[];
      final balances = <double>[];
      
      final resolvedEmployeeIds = <String>[];
      for (final id in relevantEmployeeIds) {
        final employee = employeeMap[id];
        if (employee != null) {
          resolvedEmployeeIds.add(id);
          names.add(employee.name);
          balances.add(employee.currentBalance);
        }
      }

      if (resolvedEmployeeIds.isEmpty) {
        skippedGroups++;
        continue;
      }

      // Fetch wage transactions for all production employees in these trip wages (parallel reads)
      final allTransactions = <Map<String, dynamic>>[];
      final tripWageIds = twList.map((tw) => tw.tripWageId).toSet();
      
      // Build futures for all employee/yearMonth combinations
      final futures = <Future<List<Map<String, dynamic>>>>[]; 
      final futuresMeta = <({String employeeId, String yearMonth})>[];
      
      for (final employeeId in resolvedEmployeeIds) {
        for (final yearMonth in yearMonths) {
          futures.add(
            _getMonthlyTransactionsCached(
              cache: monthlyTransactionsCache,
              employeeId: employeeId,
              financialYear: financialYear,
              yearMonth: yearMonth,
            ),
          );
          futuresMeta.add((employeeId: employeeId, yearMonth: yearMonth));
        }
      }
      
      // Fetch all in parallel
      final results = await Future.wait(futures);
      
      // Process results
      for (int i = 0; i < results.length; i++) {
        final monthlyTransactions = results[i];
        final employeeId = futuresMeta[i].employeeId;

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
        
        allTransactions.addAll(
          tripTransactions.map((tx) => {
            ...tx,
            '_employeeId': employeeId,
          }),
        );
      }

      // Convert to WeeklyLedgerTransactionRow
      final salaryTransactions = <WeeklyLedgerTransactionRow>[];
      for (final employeeId in resolvedEmployeeIds) {
        final employeeTransactions = allTransactions.where((tx) {
          return (tx['_employeeId'] as String?) == employeeId;
        });
        for (final tx in employeeTransactions) {
          final description = tx['description'] as String? ?? 'Wage credit';
          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
          final transactionId = tx['transactionId'] as String?;
          salaryTransactions.add(WeeklyLedgerTransactionRow(
            transactionId: transactionId,
            description: description,
            amount: amount,
            employeeId: employeeId,
          ));
        }
      }

      entries.add(TripLedgerEntry(
        date: date,
        vehicleNo: vehicleNo,
        tripCount: twList.length,
        employeeIds: resolvedEmployeeIds,
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
    debugPrint('[WeeklyLedgerCubit] tripEntries: grouped=${grouped.length} skipped=$skippedGroups entries=${entries.length}');
    return entries;
  }

  Future<List<Map<String, dynamic>>> _getMonthlyTransactionsCached({
    required Map<String, List<Map<String, dynamic>>> cache,
    required String employeeId,
    required String financialYear,
    required String yearMonth,
  }) async {
    final key = '$employeeId|$financialYear|$yearMonth';
    final cached = cache[key];
    if (cached != null) return cached;
    final monthlyTransactions = await _employeeWagesRepository.fetchMonthlyTransactions(
      employeeId: employeeId,
      financialYear: financialYear,
      yearMonth: yearMonth,
    );
    cache[key] = monthlyTransactions;
    return monthlyTransactions;
  }

  Future<Map<String, double>> _computeDebitsByEmployee({
    required Set<String> employeeIds,
    required DateTime start,
    required DateTime end,
    required Map<String, List<Map<String, dynamic>>> monthlyTransactionsCache,
  }) async {
    final result = <String, double>{};
    if (employeeIds.isEmpty) return result;

    final yearMonths = _getYearMonths(start, end);
    final financialYear = _getFinancialYear(start);

    // Build futures for all employee/yearMonth combinations (parallel reads)
    final futures = <Future<List<Map<String, dynamic>>>>[]; 
    final futuresMeta = <({String employeeId, String yearMonth})>[];
    
    for (final employeeId in employeeIds) {
      for (final yearMonth in yearMonths) {
        futures.add(
          _getMonthlyTransactionsCached(
            cache: monthlyTransactionsCache,
            employeeId: employeeId,
            financialYear: financialYear,
            yearMonth: yearMonth,
          ),
        );
        futuresMeta.add((employeeId: employeeId, yearMonth: yearMonth));
      }
    }
    
    // Fetch all in parallel
    final transactionResults = await Future.wait(futures);
    
    // Process results and compute totals
    final employeeTotals = <String, double>{};
    for (int i = 0; i < transactionResults.length; i++) {
      final transactions = transactionResults[i];
      final employeeId = futuresMeta[i].employeeId;

      for (final tx in transactions) {
        final date = _getTransactionDate(tx);
        if (date == null) continue;
        if (date.isBefore(start) || date.isAfter(end)) continue;
        if (_isDebitTransaction(tx)) {
          final currentTotal = employeeTotals[employeeId] ?? 0.0;
          employeeTotals[employeeId] = currentTotal + ((tx['amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
    }
    
    // Filter out zero totals and return
    employeeTotals.forEach((employeeId, total) {
      if (total > 0) result[employeeId] = total;
    });

    return result;
  }

  DateTime? _getTransactionDate(Map<String, dynamic> tx) {
    final candidates = [tx['transactionDate'], tx['createdAt']];
    for (final value in candidates) {
      if (value == null) continue;
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        if (value is DateTime) return value;
      }
    }
    return null;
  }

  bool _isDebitTransaction(Map<String, dynamic> tx) {
    final type = tx['type'] as String?;
    if (type != null && type.toLowerCase() == 'debit') return true;
    final category = tx['category'] as String?;
    if (category == null) return false;
    const debitCategories = {
      'salaryDebit',
      'employeeAdvance',
      'employeeAdjustment',
      'generalExpense',
    };
    return debitCategories.contains(category);
  }
}
