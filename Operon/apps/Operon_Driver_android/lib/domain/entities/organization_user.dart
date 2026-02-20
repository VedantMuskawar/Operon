import 'package:flutter/foundation.dart';

class OrganizationUser {
  const OrganizationUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.roleId,
    required this.roleTitle,
    required this.organizationId,
    this.employeeId,
    this.trackingEmployeeId,
    this.ledgerEmployeeIds = const <String>[],
    this.defaultLedgerEmployeeId,
  });

  final String id;
  final String name;
  final String phone;
  final String roleId;
  final String roleTitle;
  final String organizationId;
  final String? employeeId;
  final String? trackingEmployeeId;
  final List<String> ledgerEmployeeIds;
  final String? defaultLedgerEmployeeId;

  bool get isAdmin => roleTitle.toUpperCase() == 'ADMIN';

  factory OrganizationUser.fromMap(
    Map<String, dynamic> map,
    String id,
    String organizationId,
  ) {
    debugPrint('[OrganizationUser] fromMap called');
    debugPrint('[OrganizationUser] id: $id');
    debugPrint('[OrganizationUser] organizationId: $organizationId');
    debugPrint('[OrganizationUser] map keys: ${map.keys.toList()}');
    debugPrint('[OrganizationUser] map[user_name]: ${map['user_name']}');
    debugPrint('[OrganizationUser] map[user_name] type: ${map['user_name'].runtimeType}');
    debugPrint('[OrganizationUser] map[phone]: ${map['phone']}');
    debugPrint('[OrganizationUser] map[role_in_org]: ${map['role_in_org']}');
    
    final userName = map['user_name'] as String?;
    debugPrint('[OrganizationUser] userName after cast: $userName');
    final finalName = userName ?? 'Unnamed';
    debugPrint('[OrganizationUser] final name: $finalName');

    final legacyEmployeeId = map['employee_id'] as String?;
    final trackingEmployeeId =
      (map['trackingEmployeeId'] as String?) ?? legacyEmployeeId;

    final rawLedgerIds = map['ledgerEmployeeIds'];
    final parsedLedgerIds = rawLedgerIds is List
      ? rawLedgerIds
        .whereType<Object>()
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList()
      : <String>[];

    final defaultLedgerEmployeeId =
      (map['defaultLedgerEmployeeId'] as String?) ??
        (parsedLedgerIds.isNotEmpty
          ? parsedLedgerIds.first
          : trackingEmployeeId);

    final ledgerEmployeeIds = parsedLedgerIds.isNotEmpty
      ? parsedLedgerIds
      : [
        if (trackingEmployeeId != null && trackingEmployeeId.isNotEmpty)
          trackingEmployeeId,
        ];
    
    return OrganizationUser(
      id: id,
      name: finalName,
      phone: map['phone'] as String? ?? '',
      roleId: map['role_id'] as String? ?? '',
      roleTitle: map['role_in_org'] as String? ?? '',
      organizationId:
          map['organization_id'] as String? ?? organizationId,
      employeeId: legacyEmployeeId,
      trackingEmployeeId: trackingEmployeeId,
      ledgerEmployeeIds: ledgerEmployeeIds,
      defaultLedgerEmployeeId: defaultLedgerEmployeeId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_name': name,
      'phone': phone,
      'role_id': roleId,
      'role_in_org': roleTitle,
      'employee_id': employeeId,
      if (trackingEmployeeId != null)
        'trackingEmployeeId': trackingEmployeeId,
      if (ledgerEmployeeIds.isNotEmpty)
        'ledgerEmployeeIds': ledgerEmployeeIds,
      if (defaultLedgerEmployeeId != null)
        'defaultLedgerEmployeeId': defaultLedgerEmployeeId,
      'organization_id': organizationId,
    };
  }
}
