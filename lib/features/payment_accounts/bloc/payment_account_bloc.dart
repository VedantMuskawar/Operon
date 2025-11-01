import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'payment_account_event.dart';
import 'payment_account_state.dart';
import '../repositories/payment_account_repository.dart';
import '../models/payment_account.dart';

class PaymentAccountBloc extends Bloc<PaymentAccountEvent, PaymentAccountState> {
  final PaymentAccountRepository _paymentAccountRepository;

  PaymentAccountBloc({required PaymentAccountRepository paymentAccountRepository})
      : _paymentAccountRepository = paymentAccountRepository,
        super(const PaymentAccountInitial()) {
    on<LoadPaymentAccounts>(_onLoadPaymentAccounts);
    on<AddPaymentAccount>(_onAddPaymentAccount);
    on<UpdatePaymentAccount>(_onUpdatePaymentAccount);
    on<DeletePaymentAccount>(_onDeletePaymentAccount);
    on<SearchPaymentAccounts>(_onSearchPaymentAccounts);
    on<ResetSearch>(_onResetSearch);
    on<RefreshPaymentAccounts>(_onRefreshPaymentAccounts);
    on<SetDefaultAccount>(_onSetDefaultAccount);
  }

  Future<void> _onLoadPaymentAccounts(
    LoadPaymentAccounts event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountLoading());

      await emit.forEach(
        _paymentAccountRepository.getPaymentAccountsStream(event.organizationId),
        onData: (List<PaymentAccount> accounts) {
          if (accounts.isEmpty) {
            return const PaymentAccountEmpty();
          }
          return PaymentAccountLoaded(accounts: accounts);
        },
        onError: (error, stackTrace) {
          return PaymentAccountError('Failed to load payment accounts: $error');
        },
      );
    } catch (e) {
      emit(PaymentAccountError('Failed to load payment accounts: $e'));
    }
  }

  Future<void> _onAddPaymentAccount(
    AddPaymentAccount event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountOperating());

      await _paymentAccountRepository.addPaymentAccount(
        event.organizationId,
        event.account,
        event.userId,
      );

      emit(const PaymentAccountOperationSuccess('Payment account added successfully'));
    } catch (e) {
      emit(PaymentAccountError('Failed to add payment account: $e'));
    }
  }

  Future<void> _onUpdatePaymentAccount(
    UpdatePaymentAccount event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountOperating());

      await _paymentAccountRepository.updatePaymentAccount(
        event.organizationId,
        event.accountId,
        event.account,
        event.userId,
      );

      emit(const PaymentAccountOperationSuccess('Payment account updated successfully'));
    } catch (e) {
      emit(PaymentAccountError('Failed to update payment account: $e'));
    }
  }

  Future<void> _onDeletePaymentAccount(
    DeletePaymentAccount event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountOperating());

      await _paymentAccountRepository.deletePaymentAccount(
        event.organizationId,
        event.accountId,
      );

      emit(const PaymentAccountOperationSuccess('Payment account deleted successfully'));
    } catch (e) {
      emit(PaymentAccountError('Failed to delete payment account: $e'));
    }
  }

  Future<void> _onSearchPaymentAccounts(
    SearchPaymentAccounts event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountLoading());

      await emit.forEach(
        _paymentAccountRepository.searchPaymentAccounts(
          event.organizationId,
          event.query,
        ),
        onData: (List<PaymentAccount> accounts) {
          if (accounts.isEmpty) {
            return PaymentAccountEmpty(searchQuery: event.query);
          }
          return PaymentAccountLoaded(
            accounts: accounts,
            searchQuery: event.query,
          );
        },
        onError: (error, stackTrace) {
          return PaymentAccountError('Failed to search payment accounts: $error');
        },
      );
    } catch (e) {
      emit(PaymentAccountError('Failed to search payment accounts: $e'));
    }
  }

  void _onResetSearch(
    ResetSearch event,
    Emitter<PaymentAccountState> emit,
  ) {
    if (state is PaymentAccountLoaded) {
      final currentState = state as PaymentAccountLoaded;
      emit(currentState.copyWith(searchQueryReset: () => null));
    }
  }

  Future<void> _onRefreshPaymentAccounts(
    RefreshPaymentAccounts event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountLoading());

      final accounts = await _paymentAccountRepository.getPaymentAccounts(
        event.organizationId,
      );

      if (accounts.isEmpty) {
        emit(const PaymentAccountEmpty());
      } else {
        emit(PaymentAccountLoaded(accounts: accounts));
      }
    } catch (e) {
      emit(PaymentAccountError('Failed to refresh payment accounts: $e'));
    }
  }

  Future<void> _onSetDefaultAccount(
    SetDefaultAccount event,
    Emitter<PaymentAccountState> emit,
  ) async {
    try {
      emit(const PaymentAccountOperating());

      await _paymentAccountRepository.setDefaultAccount(
        event.organizationId,
        event.accountId,
      );

      emit(const PaymentAccountOperationSuccess('Default account updated successfully'));
    } catch (e) {
      emit(PaymentAccountError('Failed to set default account: $e'));
    }
  }
}

