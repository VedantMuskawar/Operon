import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class TransactionAnalyticsState extends BaseState {
  const TransactionAnalyticsState({
    super.status = ViewStatus.initial,
    this.analytics,
    super.message,
  });

  final TransactionAnalytics? analytics;

  @override
  TransactionAnalyticsState copyWith({
    ViewStatus? status,
    TransactionAnalytics? analytics,
    String? message,
  }) {
    return TransactionAnalyticsState(
      status: status ?? this.status,
      analytics: analytics ?? this.analytics,
      message: message ?? this.message,
    );
  }
}
