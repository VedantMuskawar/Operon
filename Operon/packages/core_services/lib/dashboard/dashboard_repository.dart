import 'package:core_models/core_models.dart';

abstract class DashboardRepository {
  Stream<List<DashboardMetric>> watchPrimaryMetrics();

  Future<List<UserProfile>> fetchRecentUsers();
}
