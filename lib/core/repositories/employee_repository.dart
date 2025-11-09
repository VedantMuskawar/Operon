import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_constants.dart';
import '../models/employee.dart';
import '../models/employee_role_definition.dart';

class EmployeePageResult {
  final List<Employee> employees;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const EmployeePageResult({
    required this.employees,
    required this.lastDocument,
    required this.hasMore,
  });
}

class EmployeeRepository {
  EmployeeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeesCollection =>
      _firestore.collection(AppConstants.employeesCollection);

  CollectionReference<Map<String, dynamic>> _rolesCollection(
    String organizationId,
  ) {
    return _firestore
        .collection(AppConstants.organizationsCollection)
        .doc(organizationId)
        .collection(AppConstants.rolesSubcollection);
  }

  static const _wageTypes = {
    AppConstants.employeeWageTypeHourly,
    AppConstants.employeeWageTypeQuantity,
    AppConstants.employeeWageTypeMonthly,
  };

  static const _compensationFrequencies = {
    AppConstants.employeeCompFrequencyMonthly,
    AppConstants.employeeCompFrequencyBiweekly,
    AppConstants.employeeCompFrequencyWeekly,
    AppConstants.employeeCompFrequencyPerShift,
  };

  String _normalizeWageType(String? wageType) {
    if (wageType == null || wageType.trim().isEmpty) {
      return AppConstants.employeeWageTypeMonthly;
    }
    final lower = wageType.trim().toLowerCase();
    if (_wageTypes.contains(lower)) {
      return lower;
    }
    return AppConstants.employeeWageTypeMonthly;
  }

  String _normalizeCompensationFrequency(String? frequency) {
    if (frequency == null || frequency.trim().isEmpty) {
      return AppConstants.employeeCompFrequencyMonthly;
    }
    final lower = frequency.trim().toLowerCase();
    if (_compensationFrequencies.contains(lower)) {
      return lower;
    }
    return AppConstants.employeeCompFrequencyMonthly;
  }

  Query<Map<String, dynamic>> _baseEmployeesQuery(String organizationId) {
    return _employeesCollection
        .where('organizationId', isEqualTo: organizationId)
        .orderBy('nameLowercase');
  }

  Query<Map<String, dynamic>> _applyFilters(
    Query<Map<String, dynamic>> query, {
    String? searchQuery,
    String? status,
    String? roleId,
  }) {
    if (status != null && status.trim().isNotEmpty) {
      query = query.where('status', isEqualTo: status.trim().toLowerCase());
    }

    if (roleId != null && roleId.trim().isNotEmpty) {
      query = query.where('roleId', isEqualTo: roleId.trim());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final normalized = searchQuery.trim().toLowerCase();
      final upperBound = '${normalized}\uf8ff';
      query = query
          .where('nameLowercase', isGreaterThanOrEqualTo: normalized)
          .where('nameLowercase', isLessThan: upperBound);
    }

    return query;
  }

  Future<EmployeePageResult> fetchEmployeesPage({
    required String organizationId,
    int limit = AppConstants.defaultPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? searchQuery,
    String? status,
    String? roleId,
  }) async {
    var query = _applyFilters(
      _baseEmployeesQuery(organizationId),
      searchQuery: searchQuery,
      status: status,
      roleId: roleId,
    ).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    final employees = snapshot.docs
        .map((doc) => Employee.fromFirestore(doc))
        .where((employee) => employee.name.isNotEmpty)
        .toList(growable: false);

    final lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return EmployeePageResult(
      employees: employees,
      lastDocument: lastDocument,
      hasMore: snapshot.docs.length == limit,
    );
  }

  Future<List<Employee>> fetchAllEmployees({
    required String organizationId,
    int? maxDocuments,
  }) async {
    final snapshot = await _baseEmployeesQuery(organizationId).get();
    final docs = maxDocuments != null
        ? snapshot.docs.take(maxDocuments).toList()
        : snapshot.docs;

    return docs
        .map((doc) => Employee.fromFirestore(doc))
        .where((employee) => employee.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Employee>> fetchDriverEmployees(String organizationId) async {
    final roles = await fetchRoleDefinitions(organizationId);
    final driverRoleIds = roles
        .where((role) => role.name.toLowerCase() == 'driver')
        .map((role) => role.id)
        .toSet();

    if (driverRoleIds.isEmpty) {
      return const [];
    }

    final employees = await fetchAllEmployees(organizationId: organizationId);

    return employees
        .where(
          (employee) =>
              driverRoleIds.contains(employee.roleId) &&
              employee.status == AppConstants.employeeStatusActive,
        )
        .toList(growable: false);
  }

  Future<Employee?> getEmployeeById(String employeeId) async {
    final doc = await _employeesCollection.doc(employeeId).get();
    if (!doc.exists) return null;
    return Employee.fromFirestore(doc);
  }

  Future<String> createEmployee({
    required String organizationId,
    required String name,
    required String roleId,
    required DateTime startDate,
    required double openingBalance,
    String openingBalanceCurrency = AppConstants.defaultCurrency,
    String status = AppConstants.employeeStatusActive,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    String? createdBy,
  }) async {
    final now = DateTime.now();
    final docRef = _employeesCollection.doc();
    final normalizedName = name.trim();

    final data = {
      'organizationId': organizationId,
      'employeeId': docRef.id,
      'roleId': roleId.trim(),
      'name': normalizedName,
      'nameLowercase': normalizedName.toLowerCase(),
      'startDate': Timestamp.fromDate(startDate),
      'openingBalance': openingBalance,
      'openingBalanceCurrency': openingBalanceCurrency,
      'status': status.toLowerCase(),
      if (contactEmail != null && contactEmail.trim().isNotEmpty)
        'contactEmail': contactEmail.trim(),
      if (contactPhone != null && contactPhone.trim().isNotEmpty)
        'contactPhone': contactPhone.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (createdBy != null && createdBy.trim().isNotEmpty)
        'createdBy': createdBy.trim(),
      'updatedBy': createdBy?.trim(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateEmployee(
    String employeeId, {
    String? name,
    String? roleId,
    DateTime? startDate,
    double? openingBalance,
    String? openingBalanceCurrency,
    String? status,
    String? contactEmail,
    String? contactPhone,
    String? notes,
    String? updatedBy,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) {
      final trimmed = name.trim();
      updates['name'] = trimmed;
      updates['nameLowercase'] = trimmed.toLowerCase();
    }
    if (roleId != null) {
      updates['roleId'] = roleId.trim();
    }
    if (startDate != null) {
      updates['startDate'] = Timestamp.fromDate(startDate);
    }
    if (openingBalance != null) {
      updates['openingBalance'] = openingBalance;
    }
    if (openingBalanceCurrency != null) {
      updates['openingBalanceCurrency'] = openingBalanceCurrency;
    }
    if (status != null) {
      updates['status'] = status.toLowerCase();
    }
    if (contactEmail != null) {
      final trimmed = contactEmail.trim();
      updates['contactEmail'] = trimmed.isNotEmpty ? trimmed : FieldValue.delete();
    }
    if (contactPhone != null) {
      final trimmed = contactPhone.trim();
      updates['contactPhone'] = trimmed.isNotEmpty ? trimmed : FieldValue.delete();
    }
    if (notes != null) {
      final trimmed = notes.trim();
      updates['notes'] = trimmed.isNotEmpty ? trimmed : FieldValue.delete();
    }
    if (updatedBy != null) {
      final trimmed = updatedBy.trim();
      if (trimmed.isNotEmpty) {
        updates['updatedBy'] = trimmed;
      }
    }

    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

    await _employeesCollection.doc(employeeId).update(updates);
  }

  Future<List<EmployeeRoleDefinition>> fetchRoleDefinitions(
    String organizationId,
  ) async {
    try {
      final rolesPath = _rolesCollection(organizationId).path;
      // ignore: avoid_print
      print('[EmployeeRepository] Fetching roles from $rolesPath');

      final snapshot = await _rolesCollection(organizationId).get();

      final roles = snapshot.docs
          .map(
            (doc) => EmployeeRoleDefinition.fromFirestore(
              doc,
              organizationId: organizationId,
            ),
          )
          .toList(growable: false);

      // ignore: avoid_print
      print('[EmployeeRepository] Loaded ${roles.length} role(s) for org $organizationId');
      // ignore: avoid_print
      if (roles.isEmpty && snapshot.docs.isNotEmpty) {
        final ids = snapshot.docs.map((doc) => doc.id).join(', ');
        print('[EmployeeRepository] Snapshot contained docs but parsing returned none. IDs: [$ids]');
      }
      return roles;
    } on FirebaseException catch (error) {
      // Fall back to name ordering if composite index is missing or still building.
      if (error.code == 'failed-precondition') {
        final fallbackSnapshot = await _rolesCollection(organizationId)
            .orderBy('name')
            .get();

        final roles = fallbackSnapshot.docs
            .map(
              (doc) => EmployeeRoleDefinition.fromFirestore(
                doc,
                organizationId: organizationId,
              ),
            )
            .toList(growable: false);
        // ignore: avoid_print
        print('[EmployeeRepository] Loaded ${roles.length} role(s) for org $organizationId via fallback ordering');
        return roles;
      }

      rethrow;
    }
  }

  Future<String> createRoleDefinition({
    required String organizationId,
    required String name,
    String? description,
    List<String> permissions = const [],
    bool isSystem = false,
    int? priority,
    String? createdBy,
    String wageType = AppConstants.employeeWageTypeMonthly,
    String compensationFrequency =
        AppConstants.employeeCompFrequencyMonthly,
    double? quantity,
    double? wagePerQuantity,
    double? monthlySalary,
    double? monthlyBonus,
  }) async {
    final collection = _rolesCollection(organizationId);
    final docRef = collection.doc();
    final now = DateTime.now();
    final trimmedName = name.trim();
    final normalizedWageType = _normalizeWageType(wageType);
    final normalizedFrequency =
        _normalizeCompensationFrequency(compensationFrequency);

    final data = {
      'organizationId': organizationId,
      'roleId': docRef.id,
      'name': trimmedName,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (permissions.isNotEmpty)
        'permissions': permissions.map((e) => e.trim()).toList(),
      'isSystem': isSystem,
      if (priority != null) 'priority': priority,
      'wageType': normalizedWageType,
      'compensationFrequency': normalizedFrequency,
      if (quantity != null) 'quantity': quantity,
      if (wagePerQuantity != null) 'wagePerQuantity': wagePerQuantity,
      if (monthlySalary != null) 'monthlySalary': monthlySalary,
      if (monthlyBonus != null) 'monthlyBonus': monthlyBonus,
      if (createdBy != null && createdBy.trim().isNotEmpty)
        'createdBy': createdBy.trim(),
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await docRef.set(data);
    return docRef.id;
  }

  Future<void> updateRoleDefinition(
    String organizationId,
    String roleId, {
    String? name,
    String? description,
    List<String>? permissions,
    bool? isSystem,
    int? priority,
    String? updatedBy,
    String? wageType,
    String? compensationFrequency,
    double? quantity,
    bool clearQuantity = false,
    double? wagePerQuantity,
    bool clearWagePerQuantity = false,
    double? monthlySalary,
    bool clearMonthlySalary = false,
    double? monthlyBonus,
    bool clearMonthlyBonus = false,
  }) async {
    final updates = <String, dynamic>{};

    if (name != null) {
      updates['name'] = name.trim();
    }
    if (description != null) {
      final trimmed = description.trim();
      updates['description'] =
          trimmed.isNotEmpty ? trimmed : FieldValue.delete();
    }
    if (permissions != null) {
      final cleaned = permissions
          .map((e) => e.trim())
          .where((element) => element.isNotEmpty)
          .toList();
      if (cleaned.isEmpty) {
        updates['permissions'] = FieldValue.delete();
      } else {
        updates['permissions'] = cleaned;
      }
    }
    if (isSystem != null) {
      updates['isSystem'] = isSystem;
    }
    if (priority != null) {
      updates['priority'] = priority;
    }
    if (updatedBy != null) {
      final trimmed = updatedBy.trim();
      if (trimmed.isNotEmpty) {
        updates['updatedBy'] = trimmed;
      }
    }
    if (wageType != null) {
      updates['wageType'] = _normalizeWageType(wageType);
    }
    if (compensationFrequency != null) {
      updates['compensationFrequency'] =
          _normalizeCompensationFrequency(compensationFrequency);
    }
    if (clearQuantity) {
      updates['quantity'] = FieldValue.delete();
    } else if (quantity != null) {
      updates['quantity'] = quantity;
    }
    if (clearWagePerQuantity) {
      updates['wagePerQuantity'] = FieldValue.delete();
    } else if (wagePerQuantity != null) {
      updates['wagePerQuantity'] = wagePerQuantity;
    }
    if (clearMonthlySalary) {
      updates['monthlySalary'] = FieldValue.delete();
    } else if (monthlySalary != null) {
      updates['monthlySalary'] = monthlySalary;
    }
    if (clearMonthlyBonus) {
      updates['monthlyBonus'] = FieldValue.delete();
    } else if (monthlyBonus != null) {
      updates['monthlyBonus'] = monthlyBonus;
    }

    updates['updatedAt'] = Timestamp.fromDate(DateTime.now());

    await _rolesCollection(organizationId).doc(roleId).update(updates);
  }

  Future<void> deleteRoleDefinition(
    String organizationId,
    String roleId,
  ) async {
    await _rolesCollection(organizationId).doc(roleId).delete();
  }
}

