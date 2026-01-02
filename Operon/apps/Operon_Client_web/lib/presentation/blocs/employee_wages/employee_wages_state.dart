import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class EmployeeWagesState extends BaseState {
  const EmployeeWagesState({
    super.status = ViewStatus.initial,
    this.transactions = const [],
    super.message,
  });

  final List<Transaction> transactions;

  @override
  EmployeeWagesState copyWith({
    ViewStatus? status,
    List<Transaction>? transactions,
    String? message,
  }) {
    return EmployeeWagesState(
      status: status ?? this.status,
      transactions: transactions ?? this.transactions,
      message: message,
    );
  }
}

