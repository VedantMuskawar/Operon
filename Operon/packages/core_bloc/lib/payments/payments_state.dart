import 'package:core_bloc/core_bloc.dart';

class PaymentsState {
  const PaymentsState({
    this.status = ViewStatus.initial,
    this.message,
    this.selectedClientId,
    this.selectedClientName,
    this.currentBalance,
    this.paymentAmount,
    this.paymentDate,
    this.receiptPhoto,
    this.receiptPhotoUrl,
    this.isSubmitting = false,
    this.recentPayments = const [],
    this.isLoadingPayments = false,
    this.paymentAccountSplits = const {},
  });

  final ViewStatus status;
  final String? message;
  final String? selectedClientId;
  final String? selectedClientName;
  final double? currentBalance;
  final double? paymentAmount;
  final DateTime? paymentDate;
  final String? receiptPhoto; // File path or base64
  final String? receiptPhotoUrl; // Firebase Storage URL
  final bool isSubmitting;
  final List<dynamic> recentPayments; // List of transactions (type depends on app)
  final bool isLoadingPayments;
  final Map<String, double> paymentAccountSplits; // accountId -> amount

  PaymentsState copyWith({
    ViewStatus? status,
    String? message,
    String? selectedClientId,
    String? selectedClientName,
    double? currentBalance,
    double? paymentAmount,
    DateTime? paymentDate,
    String? receiptPhoto,
    String? receiptPhotoUrl,
    bool? isSubmitting,
    List<dynamic>? recentPayments,
    bool? isLoadingPayments,
    Map<String, double>? paymentAccountSplits,
    bool clearMessage = false,
    bool clearSelectedClient = false,
    bool clearReceiptPhoto = false,
    bool clearPaymentAccountSplits = false,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      message: clearMessage ? null : (message ?? this.message),
      selectedClientId: clearSelectedClient ? null : (selectedClientId ?? this.selectedClientId),
      selectedClientName: clearSelectedClient ? null : (selectedClientName ?? this.selectedClientName),
      currentBalance: currentBalance ?? this.currentBalance,
      paymentAmount: paymentAmount ?? this.paymentAmount,
      paymentDate: paymentDate ?? this.paymentDate,
      receiptPhoto: clearReceiptPhoto ? null : (receiptPhoto ?? this.receiptPhoto),
      receiptPhotoUrl: receiptPhotoUrl ?? this.receiptPhotoUrl,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      recentPayments: recentPayments ?? this.recentPayments,
      isLoadingPayments: isLoadingPayments ?? this.isLoadingPayments,
      paymentAccountSplits: clearPaymentAccountSplits ? const {} : (paymentAccountSplits ?? this.paymentAccountSplits),
    );
  }
}


