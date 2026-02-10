import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/domain/entities/organization_employee.dart';

class EmployeesDataSource {
  EmployeesDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('EMPLOYEES');

  Future<List<OrganizationEmployee>> fetchEmployees(
      String organizationId) async {
    final snapshot = await _employeesRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('employeeName')
        .limit(500)
        .get();
    return snapshot.docs
        .map((doc) => OrganizationEmployee.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<
      ({
        List<OrganizationEmployee> employees,
        DocumentSnapshot<Map<String, dynamic>>? lastDoc,
      })> fetchEmployeesPage({
    required String organizationId,
    int limit = 30,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDocument,
  }) async {
    Query<Map<String, dynamic>> query = _employeesRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('employeeName')
        .limit(limit);

    if (startAfterDocument != null) {
      query = query.startAfterDocument(startAfterDocument);
    }

    final snapshot = await query.get();
    final employees = snapshot.docs
        .map((doc) => OrganizationEmployee.fromJson(doc.data(), doc.id))
        .toList();
    final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    return (employees: employees, lastDoc: lastDoc);
  }

  Future<List<OrganizationEmployee>> searchEmployeesByName(
    String organizationId,
    String query, {
    int limit = 30,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final snapshot = await _employeesRef
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('employeeName')
        .startAt([trimmed])
        .endAt(['$trimmed\uf8ff'])
        .limit(limit)
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
      'jobRoleIds': employee.jobRoleIds,
      'jobRoles': employee.jobRoles.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'wage': employee.wage.toJson(),
      'openingBalance': employee.openingBalance,
      'currentBalance': employee.currentBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteEmployee(String employeeId) {
    return _employeesRef.doc(employeeId).delete();
  }
}
