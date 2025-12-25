import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';

class WebDashboardRepositoryImpl implements DashboardRepository {
  @override
  Future<List<UserProfile>> fetchRecentUsers() async {
    return const [
      UserProfile(id: '1', phoneNumber: '+155555501', role: UserRole.admin),
      UserProfile(id: '2', phoneNumber: '+155555502', role: UserRole.user),
    ];
  }

  @override
  Stream<List<DashboardMetric>> watchPrimaryMetrics() {
    return const Stream.empty();
  }
}
