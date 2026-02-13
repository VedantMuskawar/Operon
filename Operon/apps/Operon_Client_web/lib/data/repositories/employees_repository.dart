import 'package:dash_web/data/datasources/employees_data_source.dart';
import 'package:dash_web/domain/entities/organization_employee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeesRepository {
  EmployeesRepository({required EmployeesDataSource dataSource})
      : _dataSource = dataSource;

  final EmployeesDataSource _dataSource;

  final Map<String, ({DateTime timestamp, List<OrganizationEmployee> data})> _cache = {};
  final Map<String, Future<List<OrganizationEmployee>>> _inFlight = {};
  static const Duration _cacheTtl = Duration(minutes: 2);

  Future<List<OrganizationEmployee>> fetchEmployees(
    String organizationId, {
    bool forceRefresh = false,
  }) {
    if (!forceRefresh) {
      final cached = _cache[organizationId];
      if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
        return Future.value(cached.data);
      }

      final inFlight = _inFlight[organizationId];
      if (inFlight != null) return inFlight;
    }

    final future = _dataSource.fetchEmployees(organizationId);
    _inFlight[organizationId] = future;
    return future.then((employees) {
      _cache[organizationId] = (timestamp: DateTime.now(), data: employees);
      _inFlight.remove(organizationId);
      return employees;
    }).catchError((e) {
      _inFlight.remove(organizationId);
      throw e;
    });
  }

  Future<
      ({
        List<OrganizationEmployee> employees,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> fetchEmployeesPage({
    required String organizationId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) {
    return _dataSource.fetchEmployeesPage(
      organizationId: organizationId,
      limit: limit,
      startAfterDocument: startAfterDocument,
    );
  }

  Future<List<OrganizationEmployee>> searchEmployeesByName(
    String organizationId,
    String query, {
    int limit = 30,
  }) {
    return _dataSource.searchEmployeesByName(
      organizationId,
      query,
      limit: limit,
    );
  }

  Future<OrganizationEmployee?> fetchEmployee(String employeeId) {
    return _dataSource.fetchEmployee(employeeId);
  }

  Future<List<OrganizationEmployee>> fetchEmployeesByJobRole(
    String organizationId,
    String jobRoleId,
  ) {
    return _dataSource.fetchEmployeesByJobRole(organizationId, jobRoleId);
  }

  Future<void> createEmployee(OrganizationEmployee employee) {
    _cache.remove(employee.organizationId);
    return _dataSource.createEmployee(employee);
  }

  Future<void> updateEmployee(OrganizationEmployee employee) {
    _cache.remove(employee.organizationId);
    return _dataSource.updateEmployee(employee);
  }

  Future<void> deleteEmployee(String employeeId) {
    _cache.clear();
    return _dataSource.deleteEmployee(employeeId);
  }
}
