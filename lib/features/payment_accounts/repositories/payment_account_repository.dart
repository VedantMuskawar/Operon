import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/payment_account.dart';

class PaymentAccountRepository {
  final FirebaseFirestore _firestore;

  PaymentAccountRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get payment accounts stream for a specific organization (subcollection)
  Stream<List<PaymentAccount>> getPaymentAccountsStream(String organizationId) {
    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PAYMENT_ACCOUNTS')
        .snapshots()
        .map((snapshot) {
      final accounts = snapshot.docs
          .map((doc) => PaymentAccount.fromFirestore(doc))
          .toList();
      // Sort accounts by accountName for consistent ordering
      accounts.sort((a, b) => a.accountName.compareTo(b.accountName));
      return accounts;
    });
  }

  // Get payment accounts once (non-stream)
  Future<List<PaymentAccount>> getPaymentAccounts(String organizationId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .get();

      final accounts = snapshot.docs
          .map((doc) => PaymentAccount.fromFirestore(doc))
          .toList();
      // Sort accounts by accountName for consistent ordering
      accounts.sort((a, b) => a.accountName.compareTo(b.accountName));
      return accounts;
    } catch (e) {
      throw Exception('Failed to fetch payment accounts: $e');
    }
  }

  // Add a new payment account
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

      // If this account is set as default, unset all other defaults
      if (account.isDefault) {
        await _unsetOtherDefaults(organizationId, docRef.id);
      }

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add payment account: $e');
    }
  }

  // Update an existing payment account
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

      // If this account is set as default, unset all other defaults
      if (account.isDefault) {
        await _unsetOtherDefaults(organizationId, accountId);
      }
    } catch (e) {
      throw Exception('Failed to update payment account: $e');
    }
  }

  // Delete a payment account
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

  // Search payment accounts by query
  Stream<List<PaymentAccount>> searchPaymentAccounts(
    String organizationId,
    String query,
  ) {
    final lowerQuery = query.toLowerCase();

    return _firestore
        .collection('ORGANIZATIONS')
        .doc(organizationId)
        .collection('PAYMENT_ACCOUNTS')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PaymentAccount.fromFirestore(doc))
          .where((account) {
        return account.accountId.toLowerCase().contains(lowerQuery) ||
            account.accountName.toLowerCase().contains(lowerQuery) ||
            account.accountType.toLowerCase().contains(lowerQuery) ||
            (account.accountNumber?.toLowerCase().contains(lowerQuery) ?? false) ||
            (account.bankName?.toLowerCase().contains(lowerQuery) ?? false);
      }).toList();
    });
  }

  // Get a single payment account by ID
  Future<PaymentAccount?> getPaymentAccountById(
    String organizationId,
    String accountId,
  ) async {
    try {
      final doc = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .doc(accountId)
          .get();

      if (!doc.exists) {
        return null;
      }

      return PaymentAccount.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to fetch payment account: $e');
    }
  }

  // Check if account ID already exists for an organization
  Future<bool> accountIdExists(String organizationId, String accountId) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .where('accountId', isEqualTo: accountId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check account ID: $e');
    }
  }

  // Set an account as default (unset all others)
  Future<void> setDefaultAccount(String organizationId, String accountId) async {
    try {
      // First, unset all defaults
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isDefault': false});
      }
      await batch.commit();

      // Then set the specified account as default
      await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .doc(accountId)
          .update({'isDefault': true});
    } catch (e) {
      throw Exception('Failed to set default account: $e');
    }
  }

  // Helper method to unset other defaults when setting a new default
  Future<void> _unsetOtherDefaults(
    String organizationId,
    String currentAccountId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('ORGANIZATIONS')
          .doc(organizationId)
          .collection('PAYMENT_ACCOUNTS')
          .where('isDefault', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;
      for (var doc in snapshot.docs) {
        if (doc.id != currentAccountId) {
          batch.update(doc.reference, {'isDefault': false});
          hasUpdates = true;
        }
      }
      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      // Log error but don't throw - setting default should not fail if unsetting others fails
      print('Warning: Failed to unset other defaults: $e');
    }
  }
}

