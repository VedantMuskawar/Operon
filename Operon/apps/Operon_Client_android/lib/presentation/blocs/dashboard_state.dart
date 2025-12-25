part of 'dashboard_bloc.dart';

class DashboardState extends BaseState {
  const DashboardState({
    super.status = ViewStatus.initial,
    this.metrics = const [],
  }) : super(message: null);

  final List<String> metrics;

  @override
  DashboardState copyWith({
    ViewStatus? status,
    String? message,
    List<String>? metrics,
  }) {
    return DashboardState(
      status: status ?? this.status,
      metrics: metrics ?? this.metrics,
    );
  }
}
