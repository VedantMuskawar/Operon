import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class TripWagesState extends BaseState {
  const TripWagesState({
    super.status = ViewStatus.initial,
    this.tripWages = const [],
    this.returnedDMs = const [],
    super.message,
  });

  final List<TripWage> tripWages;
  final List<Map<String, dynamic>> returnedDMs;

  @override
  TripWagesState copyWith({
    ViewStatus? status,
    List<TripWage>? tripWages,
    List<Map<String, dynamic>>? returnedDMs,
    String? message,
  }) {
    return TripWagesState(
      status: status ?? this.status,
      tripWages: tripWages ?? this.tripWages,
      returnedDMs: returnedDMs ?? this.returnedDMs,
      message: message,
    );
  }
}

