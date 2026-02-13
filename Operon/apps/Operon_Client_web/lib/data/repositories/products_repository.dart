import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';

class ProductsRepository {
  ProductsRepository({required ProductsDataSource dataSource})
      : _dataSource = dataSource;

  final ProductsDataSource _dataSource;

  final Map<String, ({DateTime timestamp, List<OrganizationProduct> data})>
      _cache = {};
  final Map<String, Future<List<OrganizationProduct>>> _inFlight = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<List<OrganizationProduct>> fetchProducts(
    String orgId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache[orgId];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return Future.value(cached.data);
      }

      final inFlight = _inFlight[orgId];
      if (inFlight != null) return inFlight;
    }

    final future = _dataSource.fetchProducts(orgId);
    _inFlight[orgId] = future;
    return future.then((products) {
      _cache[orgId] = (timestamp: DateTime.now(), data: products);
      _inFlight.remove(orgId);
      return products;
    }).catchError((e) {
      _inFlight.remove(orgId);
      throw e;
    });
  }

  Future<void> createProduct(String orgId, OrganizationProduct product) {
    _cache.remove(orgId);
    return _dataSource.createProduct(orgId, product);
  }

  Future<void> updateProduct(String orgId, OrganizationProduct product) {
    _cache.remove(orgId);
    return _dataSource.updateProduct(orgId, product);
  }

  Future<void> deleteProduct(String orgId, String productId) {
    _cache.remove(orgId);
    return _dataSource.deleteProduct(orgId, productId);
  }
}
