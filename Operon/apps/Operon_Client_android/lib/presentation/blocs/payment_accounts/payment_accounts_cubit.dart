import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/data/repositories/payment_accounts_repository.dart';
import 'package:dash_mobile/data/services/qr_code_service.dart';
import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PaymentAccountsState extends BaseState {
  const PaymentAccountsState({
    super.status = ViewStatus.initial,
    this.accounts = const [],
    this.message,
  }) : super(message: message);

  final List<PaymentAccount> accounts;
  @override
  final String? message;

  @override
  PaymentAccountsState copyWith({
    ViewStatus? status,
    List<PaymentAccount>? accounts,
    String? message,
  }) {
    return PaymentAccountsState(
      status: status ?? this.status,
      accounts: accounts ?? this.accounts,
      message: message ?? this.message,
    );
  }
}

class PaymentAccountsCubit extends Cubit<PaymentAccountsState> {
  PaymentAccountsCubit({
    required PaymentAccountsRepository repository,
    required QrCodeService qrCodeService,
    required String orgId,
  })  : _repository = repository,
        _qrCodeService = qrCodeService,
        _orgId = orgId,
        super(const PaymentAccountsState());

  final PaymentAccountsRepository _repository;
  final QrCodeService _qrCodeService;
  final String _orgId;

  Future<void> loadAccounts() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final accounts = await _repository.fetchAccounts(_orgId);
      emit(state.copyWith(status: ViewStatus.success, accounts: accounts));
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load payment accounts. Please try again.',
      ));
    }
  }

  Future<void> createAccount(PaymentAccount account) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      String? qrCodeUrl;

      // Generate and upload QR code if UPI ID is provided
      if (account.upiQrData != null && account.upiQrData!.isNotEmpty) {
        try {
          final qrImageBytes = await _qrCodeService.generateQrCodeImage(
            account.upiQrData!,
          );
          qrCodeUrl = await _qrCodeService.uploadQrCodeImage(
            qrImageBytes,
            _orgId,
            account.id,
          );
        } catch (e) {
          emit(state.copyWith(
            status: ViewStatus.failure,
            message: 'Failed to generate QR code: ${e.toString()}',
          ));
          return;
        }
      }

      final accountWithQr = account.copyWith(qrCodeImageUrl: qrCodeUrl);
      await _repository.createAccount(_orgId, accountWithQr);
      await loadAccounts();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create payment account.',
      ));
    }
  }

  Future<void> updateAccount(PaymentAccount account) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      String? qrCodeUrl = account.qrCodeImageUrl;

      // Regenerate QR code if UPI ID changed or doesn't exist
      if (account.upiQrData != null && account.upiQrData!.isNotEmpty) {
        try {
          // Delete old QR code if it exists
          if (qrCodeUrl != null) {
            await _qrCodeService.deleteQrCodeImage(_orgId, account.id);
          }

          // Generate and upload new QR code
          final qrImageBytes = await _qrCodeService.generateQrCodeImage(
            account.upiQrData!,
          );
          qrCodeUrl = await _qrCodeService.uploadQrCodeImage(
            qrImageBytes,
            _orgId,
            account.id,
          );
        } catch (e) {
          emit(state.copyWith(
            status: ViewStatus.failure,
            message: 'Failed to update QR code: ${e.toString()}',
          ));
          return;
        }
      } else if (qrCodeUrl != null) {
        // If UPI ID was removed, delete the QR code
        await _qrCodeService.deleteQrCodeImage(_orgId, account.id);
        qrCodeUrl = null;
      }

      final accountWithQr = account.copyWith(qrCodeImageUrl: qrCodeUrl);
      await _repository.updateAccount(_orgId, accountWithQr);
      await loadAccounts();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update payment account.',
      ));
    }
  }

  Future<void> deleteAccount(String accountId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      // Delete QR code from storage if it exists
      try {
        await _qrCodeService.deleteQrCodeImage(_orgId, accountId);
      } catch (e) {
        // Continue even if QR deletion fails
      }

      await _repository.deleteAccount(_orgId, accountId);
      await loadAccounts();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete payment account.',
      ));
    }
  }

  Future<void> setPrimaryAccount(String accountId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.setPrimaryAccount(_orgId, accountId);
      await loadAccounts();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to set primary account.',
      ));
    }
  }

  Future<void> unsetPrimaryAccount(String accountId) async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.unsetPrimaryAccount(_orgId, accountId);
      await loadAccounts();
    } catch (error) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to unset primary account.',
      ));
    }
  }
}

