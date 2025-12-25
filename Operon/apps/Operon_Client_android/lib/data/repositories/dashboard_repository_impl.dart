import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  @override
  Future<List<UserProfile>> fetchRecentUsers() async {
    return const [];
  }

  @override
  Stream<List<DashboardMetric>> watchPrimaryMetrics() {
    return Stream.value(const [
      DashboardMetric(title: 'Sessions', value: '12.4K', delta: 8.2),
    ]);
  }
}
