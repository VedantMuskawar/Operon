import 'package:core_bloc/core_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends BaseBloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(const DashboardState()) {
    on<DashboardStarted>(_onStarted);
  }

  Future<void> _onStarted(
    DashboardStarted event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(status: ViewStatus.loading));
    await Future.delayed(const Duration(milliseconds: 500));
    emit(
      state.copyWith(
        status: ViewStatus.success,
        metrics: const ['Sessions', 'Revenue', 'Latency'],
      ),
    );
  }
}
