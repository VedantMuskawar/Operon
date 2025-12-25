import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';

class FetchUsersUseCase {
  FetchUsersUseCase(this._repository);

  final DashboardRepository _repository;

  Future<List<UserProfile>> call() {
    return _repository.fetchRecentUsers();
  }
}
