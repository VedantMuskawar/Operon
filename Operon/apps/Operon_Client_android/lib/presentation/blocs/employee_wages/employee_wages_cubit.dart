import 'dart:async';

import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'employee_wages_state.dart';

class EmployeeWagesCubit extends Cubit<EmployeeWagesState> {
  EmployeeWagesCubit({
    required EmployeeWagesRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const EmployeeWagesState());

  final EmployeeWagesRepository _repository;
  final String _organizationId;
  StreamSubscription<List<Transaction>>? _transactionsSubscription;

  @override
  Future<void> close() {
    _transactionsSubscription?.cancel();
    return super.close();
  }

  /// Load transactions for the organization
  Future<void> loadTransactions({
    String? financialYear,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    emit(state.copyWith(status: ViewStatus.loading));
    try {
      final transactions = await _repository.fetchOrganizationEmployeeTransactions(
        organizationId: _organizationId,
        financialYear: financialYear,
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        transactions: transactions,
        message: null,
      ));
    } catch (e, stackTrace) {
      debugPrint('[EmployeeWagesCubit] Error loading transactions: $e');
      debugPrint('[EmployeeWagesCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to load transactions: ${e.toString()}',
      ));
    }
  }

  /// Watch transactions stream for real-time updates
  void watchTransactions({
    String? financialYear,
    int? limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _transactionsSubscription?.cancel();
    _transactionsSubscription = _repository
        .watchOrganizationEmployeeTransactions(
      organizationId: _organizationId,
      financialYear: financialYear,
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    )
        .listen(
      (transactions) {
        emit(state.copyWith(
          status: ViewStatus.success,
          transactions: transactions,
          message: null,
        ));
      },
      onError: (error) {
        debugPrint('[EmployeeWagesCubit] Error in transactions stream: $error');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load transactions: ${error.toString()}',
        ));
      },
    );
  }

  /// Create salary credit transaction
  Future<String> createSalaryTransaction({
    required String employeeId,
    String? employeeName,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final transactionId = await _repository.createSalaryTransaction(
        organizationId: _organizationId,
        employeeId: employeeId,
        employeeName: employeeName,
        amount: amount,
        paymentDate: paymentDate,
        createdBy: createdBy,
        paymentAccountId: paymentAccountId,
        paymentAccountType: paymentAccountType,
        referenceNumber: referenceNumber,
        description: description,
        metadata: metadata,
      );
      
      // Reload only when not streaming
      if (_transactionsSubscription == null) {
        await loadTransactions();
      }
      
      return transactionId;
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to credit salary: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Create bonus transaction
  Future<String> createBonusTransaction({
    required String employeeId,
    String? employeeName,
    required double amount,
    required DateTime paymentDate,
    required String createdBy,
    String? bonusType,
    String? paymentAccountId,
    String? paymentAccountType,
    String? referenceNumber,
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final transactionId = await _repository.createBonusTransaction(
        organizationId: _organizationId,
        employeeId: employeeId,
        employeeName: employeeName,
        amount: amount,
        paymentDate: paymentDate,
        createdBy: createdBy,
        bonusType: bonusType,
        paymentAccountId: paymentAccountId,
        paymentAccountType: paymentAccountType,
        referenceNumber: referenceNumber,
        description: description,
        metadata: metadata,
      );
      
      // Reload only when not streaming
      if (_transactionsSubscription == null) {
        await loadTransactions();
      }
      
      return transactionId;
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to record bonus: ${e.toString()}',
      ));
      rethrow;
    }
  }

  /// Check if salary already credited for a month
  Future<bool> isSalaryCreditedForMonth({
    required String employeeId,
    required int year,
    required int month,
  }) async {
    try {
      return await _repository.isSalaryCreditedForMonth(
        organizationId: _organizationId,
        employeeId: employeeId,
        year: year,
        month: month,
      );
    } catch (e) {
      debugPrint('[EmployeeWagesCubit] Error checking salary credit: $e');
      return false;
    }
  }

  /// Delete a transaction
  Future<void> deleteTransaction(String transactionId) async {
    try {
      await _repository.deleteTransaction(transactionId);
      // Streams will auto-update via watchTransactions, no manual refresh needed
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete transaction: ${e.toString()}',
      ));
      rethrow;
    }
  }
}

