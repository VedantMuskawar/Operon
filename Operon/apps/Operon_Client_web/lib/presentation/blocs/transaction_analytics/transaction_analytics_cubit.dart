import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/data/repositories/analytics_repository.dart';
import 'package:dash_web/data/utils/financial_year_utils.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'transaction_analytics_state.dart';

class TransactionAnalyticsCubit extends Cubit<TransactionAnalyticsState> {
  TransactionAnalyticsCubit({
    required AnalyticsRepository analyticsRepository,
  })  : _analyticsRepository = analyticsRepository,
        super(const TransactionAnalyticsState());

  final AnalyticsRepository _analyticsRepository;

  /// Load transaction analytics for the given org and FY.
  /// Use [financialYear] or default to current FY.
  Future<void> load({
    required String orgId,
    String? financialYear,
  }) async {
    final fy = financialYear ?? FinancialYearUtils.getCurrentFinancialYear();
    if (orgId.isEmpty) {
      emit(state.copyWith(status: ViewStatus.success, analytics: null));
      return;
    }
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final analytics = await _analyticsRepository.fetchTransactionAnalytics(orgId, fy);
      emit(state.copyWith(
        status: ViewStatus.success,
        analytics: analytics,
        message: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: e.toString(),
      ));
    }
  }
}
