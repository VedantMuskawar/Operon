import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_web/domain/entities/payment_account.dart';

/// Data source for payment accounts (PAYMENT_ACCOUNTS subcollection).
/// Queries are capped at 500; document count per org is expected to be low (<50). Monitor if growth is possible.
class PaymentAccountsDataSource {
  PaymentAccountsDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _accountsRef(String orgId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(orgId)
        .collection('PAYMENT_ACCOUNTS');
  }

  Future<List<PaymentAccount>> fetchAccounts(String orgId) async {
    final snapshot = await _accountsRef(orgId).orderBy('name').limit(500).get();
    return snapshot.docs
        .map((doc) => PaymentAccount.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<void> createAccount(String orgId, PaymentAccount account) {
    return _accountsRef(orgId).doc(account.id).set({
      ...account.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateAccount(String orgId, PaymentAccount account) {
    return _accountsRef(orgId).doc(account.id).update({
      ...account.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAccount(String orgId, String accountId) {
    return _accountsRef(orgId).doc(accountId).delete();
  }

  /// Set an account as primary (transactional - unsets all others)
  Future<void> setPrimaryAccount(String orgId, String accountId) async {
    final accountsRef = _accountsRef(orgId);

    // Fetch all accounts first
    final snapshot = await accountsRef.get();

    // Use batch write for atomic updates
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      if (doc.id == accountId) {
        // Set this one as primary
        batch.update(doc.reference, {
          'isPrimary': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Unset primary for others
        final data = doc.data();
        if (data['isPrimary'] == true) {
          batch.update(doc.reference, {
            'isPrimary': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }

    return batch.commit();
  }

  /// Unset primary status for an account
  Future<void> unsetPrimaryAccount(String orgId, String accountId) {
    return _accountsRef(orgId).doc(accountId).update({
      'isPrimary': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
