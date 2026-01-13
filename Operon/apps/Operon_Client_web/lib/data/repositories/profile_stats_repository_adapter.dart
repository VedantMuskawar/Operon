import 'package:core_bloc/home/home_cubit.dart';
import 'package:dash_web/data/repositories/pending_orders_repository.dart';

/// Adapter to bridge app-specific PendingOrdersRepository to shared ProfileStatsRepository interface
class ProfileStatsRepositoryAdapter implements ProfileStatsRepository {
  ProfileStatsRepositoryAdapter({
    required PendingOrdersRepository pendingOrdersRepository,
  }) : _pendingOrdersRepository = pendingOrdersRepository;

  final PendingOrdersRepository _pendingOrdersRepository;

  @override
  Future<int> getPendingOrdersCount(String orgId) {
    return _pendingOrdersRepository.getPendingOrdersCount(orgId);
  }
}
