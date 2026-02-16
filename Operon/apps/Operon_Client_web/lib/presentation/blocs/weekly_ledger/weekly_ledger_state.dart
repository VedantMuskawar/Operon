import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/domain/entities/weekly_ledger_entry.dart';

class WeeklyLedgerState extends BaseState {
  const WeeklyLedgerState({
    super.status = ViewStatus.initial,
    super.message,
    this.weekStart,
    this.weekEnd,
    this.productionEntries = const [],
    this.tripEntries = const [],
    this.debitByEmployeeId = const {},
    this.currentBalanceByEmployeeId = const {},
  });

  final DateTime? weekStart;
  final DateTime? weekEnd;
  final List<ProductionLedgerEntry> productionEntries;
  final List<TripLedgerEntry> tripEntries;
  final Map<String, double> debitByEmployeeId;
  final Map<String, double> currentBalanceByEmployeeId;

  bool get hasData =>
      productionEntries.isNotEmpty || tripEntries.isNotEmpty;

  @override
  WeeklyLedgerState copyWith({
    ViewStatus? status,
    String? message,
    DateTime? weekStart,
    DateTime? weekEnd,
    List<ProductionLedgerEntry>? productionEntries,
    List<TripLedgerEntry>? tripEntries,
    Map<String, double>? debitByEmployeeId,
    Map<String, double>? currentBalanceByEmployeeId,
  }) {
    return WeeklyLedgerState(
      status: status ?? this.status,
      message: message ?? this.message,
      weekStart: weekStart ?? this.weekStart,
      weekEnd: weekEnd ?? this.weekEnd,
      productionEntries: productionEntries ?? this.productionEntries,
      tripEntries: tripEntries ?? this.tripEntries,
      debitByEmployeeId: debitByEmployeeId ?? this.debitByEmployeeId,
      currentBalanceByEmployeeId:
          currentBalanceByEmployeeId ?? this.currentBalanceByEmployeeId,
    );
  }
}
