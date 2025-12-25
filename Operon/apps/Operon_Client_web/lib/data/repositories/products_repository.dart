import 'package:dash_web/data/datasources/products_data_source.dart';
import 'package:dash_web/domain/entities/organization_product.dart';

class ProductsRepository {
  ProductsRepository({required ProductsDataSource dataSource})
      : _dataSource = dataSource;

  final ProductsDataSource _dataSource;

  Future<List<OrganizationProduct>> fetchProducts(String orgId) {
    return _dataSource.fetchProducts(orgId);
  }

  Future<void> createProduct(String orgId, OrganizationProduct product) {
    return _dataSource.createProduct(orgId, product);
  }

  Future<void> updateProduct(String orgId, OrganizationProduct product) {
    return _dataSource.updateProduct(orgId, product);
  }

  Future<void> deleteProduct(String orgId, String productId) {
    return _dataSource.deleteProduct(orgId, productId);
  }
}
