import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreUserChecker {
  FirestoreUserChecker({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String usersCollection = 'USERS';

  Future<FirestoreUserRecord?> fetchUserByPhone(
    String phoneNumber,
  ) async {
    final query = await _firestore
        .collection(usersCollection)
        .where('phone', isEqualTo: phoneNumber)
        .limit(1)
        .get();
    if (query.docs.isEmpty) {
      return null;
    }
    final doc = query.docs.first;
    final data = doc.data();
    return FirestoreUserRecord(
      id: doc.id,
      phone: data['phone'] as String?,
      uid: data['uid'] as String?,
    );
  }

  Future<void> updateUserUid({
    required String documentId,
    required String uid,
  }) async {
    await _firestore.collection(usersCollection).doc(documentId).update({
      'uid': uid,
    });
  }
}

class FirestoreUserRecord {
  const FirestoreUserRecord({
    required this.id,
    this.phone,
    this.uid,
  });

  final String id;
  final String? phone;
  final String? uid;
}

