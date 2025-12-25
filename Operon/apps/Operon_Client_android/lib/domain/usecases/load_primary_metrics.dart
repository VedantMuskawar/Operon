import 'package:core_models/core_models.dart';
import 'package:core_services/core_services.dart';

class LoadPrimaryMetrics {
  LoadPrimaryMetrics(this._repository);

  final DashboardRepository _repository;

  Stream<List<DashboardMetric>> call() {
    return _repository.watchPrimaryMetrics();
  }
}
