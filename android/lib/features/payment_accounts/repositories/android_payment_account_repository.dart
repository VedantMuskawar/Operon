import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_account.dart';

class AndroidPaymentAccountRepository {
  final FirebaseFirestore _firestore;

  AndroidPaymentAccountRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<PaymentAccount>> getPaymentAccountsStream(String organizationId) {
    print('Getting payment accounts stream for orgId: $organizationId');
    try {
      return _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .snapshots()
          .map((snapshot) {
        print('Payment accounts snapshot received: ${snapshot.docs.length} documents');
        try {
          final accounts = <PaymentAccount>[];
          for (var doc in snapshot.docs) {
            try {
              final account = PaymentAccount.fromFirestore(doc);
              accounts.add(account);
              print('Parsed account: ${account.accountName}');
            } catch (e) {
              print('Error parsing payment account document ${doc.id}: $e');
              print('Document data: ${doc.data()}');
            }
          }
          accounts.sort((a, b) => a.accountName.compareTo(b.accountName));
          print('Returning ${accounts.length} payment accounts');
          return accounts;
        } catch (e) {
          print('Error processing payment accounts stream: $e');
          return <PaymentAccount>[];
        }
      }).handleError((error) {
        print('Error in payment accounts stream: $error');
        return <PaymentAccount>[];
      });
    } catch (e) {
      print('Error creating payment accounts stream: $e');
      return Stream.value(<PaymentAccount>[]);
    }
  }

  Future<String> addPaymentAccount(
    String organizationId,
    PaymentAccount account,
    String userId,
  ) async {
    try {
      final accountWithUser = PaymentAccount(
        id: account.id,
        accountId: account.accountId,
        accountName: account.accountName,
        accountType: account.accountType,
        accountNumber: account.accountNumber,
        bankName: account.bankName,
        ifscCode: account.ifscCode,
        currency: account.currency,
        status: account.status,
        isDefault: account.isDefault,
        staticQr: account.staticQr,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final docRef = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .add(accountWithUser.toFirestore());

      if (account.isDefault) {
        await _unsetOtherDefaults(organizationId, docRef.id);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add payment account: $e');
    }
  }

  Future<void> updatePaymentAccount(
    String organizationId,
    String accountId,
    PaymentAccount account,
    String userId,
  ) async {
    try {
      final accountWithUser = account.copyWith(
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .doc(accountId)
          .update(accountWithUser.toFirestore());

      if (account.isDefault) {
        await _unsetOtherDefaults(organizationId, accountId);
      }
    } catch (e) {
      throw Exception('Failed to update payment account: $e');
    }
  }

  Future<void> deletePaymentAccount(String organizationId, String accountId) async {
    try {
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .doc(accountId)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete payment account: $e');
    }
  }

  Future<void> _unsetOtherDefaults(String organizationId, String currentAccountId) async {
    final snapshot = await _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PAYMENT_ACCOUNTS')
        .where('isDefault', isEqualTo: true)
        .get();

    final batch = _firestore.batch();
    for (var doc in snapshot.docs) {
      if (doc.id != currentAccountId) {
        batch.update(doc.reference, {'isDefault': false});
      }
    }
    await batch.commit();
  }
}

