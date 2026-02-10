import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeesRepository {
  EmployeesRepository({required EmployeesDataSource dataSource})
      : _dataSource = dataSource;

  final EmployeesDataSource _dataSource;

  Future<List<OrganizationEmployee>> fetchEmployees(String organizationId) {
    return _dataSource.fetchEmployees(organizationId);
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

  Future<void> createEmployee(OrganizationEmployee employee) {
    return _dataSource.createEmployee(employee);
  }

  Future<void> updateEmployee(OrganizationEmployee employee) {
    return _dataSource.updateEmployee(employee);
  }

  Future<void> deleteEmployee(String employeeId) {
    return _dataSource.deleteEmployee(employeeId);
  }
}
