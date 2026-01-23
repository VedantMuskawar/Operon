import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_models/core_models.dart';

class NotificationDataSource {
  NotificationDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _notificationsCollection(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('NOTIFICATIONS');
  }

  Future<List<Notification>> fetchNotifications({
    required String orgId,
    required String userId,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _notificationsCollection(orgId)
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => Notification.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<Notification>> fetchUnreadNotifications({
    required String orgId,
    required String userId,
  }) async {
    final snapshot = await _notificationsCollection(orgId)
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .orderBy('created_at', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Notification.fromMap(doc.data(), doc.id))
        .toList();
  }

  Stream<int> watchUnreadCount({
    required String orgId,
    required String userId,
  }) {
    return _notificationsCollection(orgId)
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<Notification>> watchNotifications({
    required String orgId,
    required String userId,
    int? limit,
  }) {
    Query<Map<String, dynamic>> query = _notificationsCollection(orgId)
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Notification.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<void> markAsRead({
    required String orgId,
    required String notificationId,
  }) async {
    await _notificationsCollection(orgId).doc(notificationId).update({
      'is_read': true,
      'read_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markAllAsRead({
    required String orgId,
    required String userId,
  }) async {
    final unreadSnapshot = await _notificationsCollection(orgId)
        .where('user_id', isEqualTo: userId)
        .where('is_read', isEqualTo: false)
        .get();

    if (unreadSnapshot.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (final doc in unreadSnapshot.docs) {
      batch.update(doc.reference, {
        'is_read': true,
        'read_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
