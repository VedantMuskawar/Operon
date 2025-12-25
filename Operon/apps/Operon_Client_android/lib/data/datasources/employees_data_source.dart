import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';

class EmployeesDataSource {
  EmployeesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('EMPLOYEES');

  Future<List<OrganizationEmployee>> fetchEmployees(String organizationId) async {
    final snapshot = await _employeesRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('employeeName')
        .get();
    return snapshot.docs
        .map((doc) => OrganizationEmployee.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createEmployee(OrganizationEmployee employee) async {
    await _employeesRef.doc(employee.id).set({
      ...employee.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateEmployee(OrganizationEmployee employee) async {
    await _employeesRef.doc(employee.id).update({
      'employeeName': employee.name,
      'roleId': employee.roleId,
      'roleTitle': employee.roleTitle,
      'salaryType': employee.salaryType.name,
      'salaryAmount': employee.salaryAmount,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEmployee(String employeeId) {
    return _employeesRef.doc(employeeId).delete();
  }
}

