part of 'dashboard_bloc.dart';

abstract class DashboardEvent {
  const DashboardEvent();
}

class DashboardStarted extends DashboardEvent {
  const DashboardStarted();
}
