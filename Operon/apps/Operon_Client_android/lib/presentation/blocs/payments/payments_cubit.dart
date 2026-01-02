import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_bloc/core_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';

class PaymentsCubit extends Cubit<PaymentsState> {
  PaymentsCubit({
    required TransactionsRepository transactionsRepository,
    required ClientLedgerRepository clientLedgerRepository,
    required String organizationId,
  })  : _transactionsRepository = transactionsRepository,
        _clientLedgerRepository = clientLedgerRepository,
        _organizationId = organizationId,
        super(const PaymentsState());

  final TransactionsRepository _transactionsRepository;
  final ClientLedgerRepository _clientLedgerRepository;
  final String _organizationId;

  final ImagePicker _imagePicker = ImagePicker();

  /// Get current financial year
  String _getCurrentFinancialYear() {
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;
    final fyStartYear = month >= 4 ? year : year - 1;
    final fyEndYear = fyStartYear + 1;
    final startStr = (fyStartYear % 100).toString().padLeft(2, '0');
    final endStr = (fyEndYear % 100).toString().padLeft(2, '0');
    return 'FY$startStr$endStr';
  }

  /// Select client and fetch current balance
  Future<void> selectClient(ClientRecord client) async {
    emit(state.copyWith(
      selectedClientId: client.id,
      selectedClientName: client.name,
      currentBalance: null,
      status: ViewStatus.loading,
    ));

    try {
      final ledger = await _clientLedgerRepository.fetchClientLedger(
        _organizationId,
        client.id,
      );

      final balance = ledger?['currentBalance'] as num?;
      final currentBalance = balance?.toDouble() ?? 0.0;

      emit(state.copyWith(
        currentBalance: currentBalance,
        paymentDate: DateTime.now(),
        status: ViewStatus.success,
        clearMessage: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to fetch client balance: ${e.toString()}',
      ));
    }
  }

  /// Update payment amount
  void updatePaymentAmount(double? amount) {
    emit(state.copyWith(paymentAmount: amount));
  }

  /// Update payment date
  void updatePaymentDate(DateTime? date) {
    emit(state.copyWith(paymentDate: date));
  }

  /// Pick receipt photo from gallery
  Future<void> pickReceiptPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image != null) {
        emit(state.copyWith(receiptPhoto: image.path));
      }
    } catch (e) {
      emit(state.copyWith(
        message: 'Failed to pick image: ${e.toString()}',
      ));
    }
  }

  /// Take receipt photo with camera
  Future<void> takeReceiptPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );

      if (image != null) {
        emit(state.copyWith(receiptPhoto: image.path));
      }
    } catch (e) {
      emit(state.copyWith(
        message: 'Failed to take photo: ${e.toString()}',
      ));
    }
  }

  /// Remove receipt photo
  void removeReceiptPhoto() {
    emit(state.copyWith(clearReceiptPhoto: true));
  }

  /// Update payment account split
  void updatePaymentAccountSplit(String accountId, double? amount) {
    final splits = Map<String, double>.from(state.paymentAccountSplits);
    if (amount == null || amount <= 0) {
      splits.remove(accountId);
    } else {
      splits[accountId] = amount;
    }
    emit(state.copyWith(paymentAccountSplits: splits));
  }

  /// Remove payment account split
  void removePaymentAccountSplit(String accountId) {
    final splits = Map<String, double>.from(state.paymentAccountSplits);
    splits.remove(accountId);
    emit(state.copyWith(paymentAccountSplits: splits));
  }

  /// Clear all payment account splits
  void clearPaymentAccountSplits() {
    emit(state.copyWith(clearPaymentAccountSplits: true));
  }

  /// Upload photo to Firebase Storage
  Future<String?> _uploadPhoto(String filePath, String transactionId) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      if (state.selectedClientId == null) {
        throw Exception('Client ID is required for photo upload');
      }
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payments')
          .child(_organizationId)
          .child(state.selectedClientId!)
          .child(transactionId)
          .child('receipt.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload photo: ${e.toString()}');
    }
  }

  /// Submit payment
  Future<void> submitPayment() async {
    if (state.selectedClientId == null) {
      emit(state.copyWith(
        message: 'Please select a client',
        status: ViewStatus.failure,
      ));
      return;
    }

    if (state.paymentAmount == null || state.paymentAmount! <= 0) {
      emit(state.copyWith(
        message: 'Please enter a valid payment amount',
        status: ViewStatus.failure,
      ));
      return;
    }

    if (state.paymentDate == null) {
      emit(state.copyWith(
        message: 'Please select a payment date',
        status: ViewStatus.failure,
      ));
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      emit(state.copyWith(
        message: 'User not authenticated',
        status: ViewStatus.failure,
      ));
      return;
    }

    emit(state.copyWith(isSubmitting: true, status: ViewStatus.loading));

    try {
      final financialYear = _getCurrentFinancialYear();
      final now = DateTime.now();

      // Create transaction (without photo URL first)
      final transaction = Transaction(
        id: '', // Will be set by repository
        organizationId: _organizationId,
        clientId: state.selectedClientId!,
        ledgerType: LedgerType.clientLedger,
        type: TransactionType.debit, // Debit = client paid us (decreases receivable)
        category: TransactionCategory.clientPayment, // General payment recorded manually
        amount: state.paymentAmount!,
        financialYear: financialYear,
        createdAt: now,
        updatedAt: now,
        createdBy: currentUser.uid,
        metadata: {
          'recordedVia': 'quick-action',
          'photoUploaded': state.receiptPhoto != null,
          if (state.paymentAccountSplits.isNotEmpty)
            'paymentAccounts': state.paymentAccountSplits.entries.map((e) => {
                  'accountId': e.key,
                  'amount': e.value,
                }).toList(),
        },
      );

      // Create transaction first to get ID for photo upload
      final transactionId = await _transactionsRepository.createTransaction(transaction);

      // Upload photo if provided (optional - payment is already recorded)
      String? photoUrl;
      bool photoUploadFailed = false;
      String? photoUploadError;
      
      if (state.receiptPhoto != null && state.selectedClientId != null) {
        try {
          photoUrl = await _uploadPhoto(state.receiptPhoto!, transactionId);
          
          // Update transaction with photo URL in metadata
          final updatedMetadata = {
            ...transaction.metadata ?? {},
            'receiptPhotoUrl': photoUrl,
            'receiptPhotoPath': 'payments/$_organizationId/${state.selectedClientId}/$transactionId/receipt.jpg',
          };
          
          // Update the transaction document directly with photo URL
          await FirebaseFirestore.instance
              .collection('TRANSACTIONS')
              .doc(transactionId)
              .update({
            'metadata': updatedMetadata,
          });
        } catch (e) {
          // Photo upload failed, but transaction is already created successfully
          // Payment is recorded - photo upload is optional
          photoUploadFailed = true;
          photoUploadError = e.toString();
        }
      }

      // Payment is always recorded successfully (photo upload is optional)
      emit(state.copyWith(
        isSubmitting: false,
        status: ViewStatus.success,
        receiptPhotoUrl: photoUrl,
        message: photoUploadFailed
            ? 'Payment recorded successfully. Photo upload failed: $photoUploadError'
            : 'Payment recorded successfully',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        status: ViewStatus.failure,
        message: 'Failed to record payment: ${e.toString()}',
      ));
    }
  }

  /// Reset form
  void resetForm() {
    emit(const PaymentsState());
  }

  /// Load recent payments
  Future<void> loadRecentPayments({int limit = 50}) async {
    emit(state.copyWith(isLoadingPayments: true));

    try {
      // Load ALL transactions for the organization (not just payments)
      // Temporarily removed financialYear filter to debug
      debugPrint('[PaymentsCubit] Loading transactions for org: $_organizationId');
      
      final transactions = await _transactionsRepository.getOrganizationTransactions(
        organizationId: _organizationId,
        financialYear: null, // Temporarily removed to see if there are any transactions at all
        limit: limit,
      );

      debugPrint('[PaymentsCubit] Loaded ${transactions.length} transactions');
      debugPrint('[PaymentsCubit] Transaction types: ${transactions.map((t) => t.runtimeType).toList()}');

      final newState = state.copyWith(
        recentPayments: transactions,
        isLoadingPayments: false,
        status: ViewStatus.success,
        clearMessage: true,
      );
      
      debugPrint('[PaymentsCubit] New state recentPayments.length: ${newState.recentPayments.length}');
      emit(newState);
    } catch (e, stackTrace) {
      debugPrint('[PaymentsCubit] Error loading transactions: $e');
      debugPrint('[PaymentsCubit] Stack trace: $stackTrace');
      emit(state.copyWith(
        isLoadingPayments: false,
        status: ViewStatus.failure,
        message: 'Failed to load transactions: ${e.toString()}',
      ));
    }
  }
}

