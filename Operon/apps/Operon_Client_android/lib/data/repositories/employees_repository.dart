import 'package:dash_mobile/data/datasources/employees_data_source.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';

class EmployeesRepository {
  EmployeesRepository({required EmployeesDataSource dataSource})
      : _dataSource = dataSource;

  final EmployeesDataSource _dataSource;

  Future<List<OrganizationEmployee>> fetchEmployees(String organizationId) {
    return _dataSource.fetchEmployees(organizationId);
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

