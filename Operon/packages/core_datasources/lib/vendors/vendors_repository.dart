import 'package:core_models/core_models.dart';
import 'vendors_data_source.dart';

class VendorsRepository {
  VendorsRepository({required VendorsDataSource dataSource})
      : _dataSource = dataSource;

  final VendorsDataSource _dataSource;

  Future<List<Vendor>> fetchVendors(String organizationId) {
    return _dataSource.fetchVendors(organizationId);
  }

  Stream<List<Vendor>> watchVendors(String organizationId) {
    return _dataSource.watchVendors(organizationId);
  }

  Future<List<Vendor>> searchVendors(String organizationId, String query) {
    return _dataSource.searchVendors(organizationId, query);
  }

  Future<List<Vendor>> filterVendorsByType(
    String organizationId,
    VendorType? vendorType,
  ) {
    return _dataSource.filterVendorsByType(organizationId, vendorType);
  }

  Future<List<Vendor>> filterVendorsByStatus(
    String organizationId,
    VendorStatus? status,
  ) {
    return _dataSource.filterVendorsByStatus(organizationId, status);
  }

  Future<Vendor?> getVendor(String vendorId) {
    return _dataSource.getVendor(vendorId);
  }

  Future<String> createVendor(Vendor vendor) {
    return _dataSource.createVendor(vendor);
  }

  Future<void> updateVendor(Vendor vendor) {
    return _dataSource.updateVendor(vendor);
  }

  Future<void> deleteVendor(String vendorId) {
    return _dataSource.deleteVendor(vendorId);
  }
}




