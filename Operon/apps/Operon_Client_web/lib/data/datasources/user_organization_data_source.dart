import 'package:cloud_firestore/cloud_firestore.dart';

class UserOrganizationDataSource {
  UserOrganizationDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String usersCollection = 'USERS';
  static const String organizationsCollection = 'ORGANIZATIONS';

  Future<List<UserOrganizationRecord>> fetchUserOrganizations({
    required String userUid,
    String? phoneNumber,
  }) async {
    final userDocId = await _resolveUserDocumentId(
      userUid: userUid,
      phoneNumber: phoneNumber,
    );
    if (userDocId == null) {
      return const [];
    }

    final snapshot = await _firestore
        .collection(usersCollection)
        .doc(userDocId)
        .collection(organizationsCollection)
        .orderBy('org_name')
        .get();

    return snapshot.docs
        .map(
          (doc) {
            final data = doc.data();
            return UserOrganizationRecord(
              id: doc.id,
              name: data['org_name'] as String? ?? 'Untitled Org',
              role: data['role_in_org'] as String? ?? 'member',
              appAccessRoleId: data['app_access_role_id'] as String?,
            );
          },
        )
        .toList();
  }

  Future<String?> _resolveUserDocumentId({
    required String userUid,
    String? phoneNumber,
  }) async {
    final uidQuery = await _firestore
        .collection(usersCollection)
        .where('uid', isEqualTo: userUid)
        .limit(1)
        .get();
    if (uidQuery.docs.isNotEmpty) {
      return uidQuery.docs.first.id;
    }

    if (phoneNumber != null && phoneNumber.isNotEmpty) {
      for (final candidate in _phoneCandidates(phoneNumber)) {
        final phoneQuery = await _firestore
            .collection(usersCollection)
            .where('phone', isEqualTo: candidate)
            .limit(1)
            .get();
        if (phoneQuery.docs.isNotEmpty) {
          return phoneQuery.docs.first.id;
        }
      }
    }

    final directDoc =
        await _firestore.collection(usersCollection).doc(userUid).get();
    if (directDoc.exists) {
      return directDoc.id;
    }

    return null;
  }

  Iterable<String> _phoneCandidates(String phone) {
    final trimmed = phone.trim();
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9+]'), '');
    final Set<String> candidates = {trimmed};
    if (digitsOnly.isNotEmpty) {
      candidates.add(digitsOnly);
      final numericOnly = digitsOnly.replaceAll(RegExp(r'[^0-9]'), '');
      candidates.add(numericOnly);
      if (!numericOnly.startsWith('+') && numericOnly.isNotEmpty) {
        candidates.add('+$numericOnly');
      }
    }
    return candidates.where((element) => element.isNotEmpty);
  }
}

class UserOrganizationRecord {
  const UserOrganizationRecord({
    required this.id,
    required this.name,
    required this.role,
    this.appAccessRoleId,
  });

  final String id;
  final String name;
  final String role;
  final String? appAccessRoleId;
}
