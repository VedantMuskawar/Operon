import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repositories/android_payment_account_repository.dart';
import '../models/payment_account.dart';

abstract class AndroidPaymentAccountEvent extends Equatable {
  const AndroidPaymentAccountEvent();
  @override
  List<Object?> get props => [];
}

class AndroidLoadPaymentAccounts extends AndroidPaymentAccountEvent {
  final String organizationId;
  const AndroidLoadPaymentAccounts(this.organizationId);
  @override
  List<Object?> get props => [organizationId];
}

class AndroidAddPaymentAccount extends AndroidPaymentAccountEvent {
  final String organizationId;
  final PaymentAccount account;
  final String userId;
  const AndroidAddPaymentAccount({
    required this.organizationId,
    required this.account,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, account, userId];
}

class AndroidUpdatePaymentAccount extends AndroidPaymentAccountEvent {
  final String organizationId;
  final String accountId;
  final PaymentAccount account;
  final String userId;
  const AndroidUpdatePaymentAccount({
    required this.organizationId,
    required this.accountId,
    required this.account,
    required this.userId,
  });
  @override
  List<Object?> get props => [organizationId, accountId, account, userId];
}

class AndroidDeletePaymentAccount extends AndroidPaymentAccountEvent {
  final String organizationId;
  final String accountId;
  const AndroidDeletePaymentAccount({
    required this.organizationId,
    required this.accountId,
  });
  @override
  List<Object?> get props => [organizationId, accountId];
}

abstract class AndroidPaymentAccountState extends Equatable {
  const AndroidPaymentAccountState();
  @override
  List<Object?> get props => [];
}

class AndroidPaymentAccountInitial extends AndroidPaymentAccountState {}
class AndroidPaymentAccountLoading extends AndroidPaymentAccountState {}
class AndroidPaymentAccountLoaded extends AndroidPaymentAccountState {
  final List<PaymentAccount> accounts;
  const AndroidPaymentAccountLoaded({required this.accounts});
  @override
  List<Object?> get props => [accounts];
}
class AndroidPaymentAccountOperating extends AndroidPaymentAccountState {}
class AndroidPaymentAccountOperationSuccess extends AndroidPaymentAccountState {
  final String message;
  const AndroidPaymentAccountOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidPaymentAccountError extends AndroidPaymentAccountState {
  final String message;
  const AndroidPaymentAccountError(this.message);
  @override
  List<Object?> get props => [message];
}
class AndroidPaymentAccountEmpty extends AndroidPaymentAccountState {}

class AndroidPaymentAccountBloc extends Bloc<AndroidPaymentAccountEvent, AndroidPaymentAccountState> {
  final AndroidPaymentAccountRepository _repository;

  AndroidPaymentAccountBloc({required AndroidPaymentAccountRepository repository})
      : _repository = repository,
        super(AndroidPaymentAccountInitial()) {
    on<AndroidLoadPaymentAccounts>(_onLoadPaymentAccounts);
    on<AndroidAddPaymentAccount>(_onAddPaymentAccount);
    on<AndroidUpdatePaymentAccount>(_onUpdatePaymentAccount);
    on<AndroidDeletePaymentAccount>(_onDeletePaymentAccount);
  }

  Future<void> _onLoadPaymentAccounts(
    AndroidLoadPaymentAccounts event,
    Emitter<AndroidPaymentAccountState> emit,
  ) async {
    try {
      emit(AndroidPaymentAccountLoading());
      await emit.forEach(
        _repository.getPaymentAccountsStream(event.organizationId),
        onData: (List<PaymentAccount> accounts) {
          print('Payment accounts stream received ${accounts.length} accounts');
          final state = accounts.isEmpty 
              ? AndroidPaymentAccountEmpty() 
              : AndroidPaymentAccountLoaded(accounts: accounts);
          print('Emitting payment account state: ${state.runtimeType}');
          emit(state);
          return state;
        },
        onError: (error, stackTrace) {
          print('Error in payment accounts stream: $error');
          final errorState = AndroidPaymentAccountError('Failed to load accounts: $error');
          emit(errorState);
          return errorState;
        },
      );
    } catch (e) {
      emit(AndroidPaymentAccountError('Failed to load accounts: $e'));
    }
  }

  Future<void> _onAddPaymentAccount(
    AndroidAddPaymentAccount event,
    Emitter<AndroidPaymentAccountState> emit,
  ) async {
    try {
      emit(AndroidPaymentAccountOperating());
      await _repository.addPaymentAccount(event.organizationId, event.account, event.userId);
      emit(AndroidPaymentAccountOperationSuccess('Payment account added successfully'));
    } catch (e) {
      emit(AndroidPaymentAccountError('Failed to add account: $e'));
    }
  }

  Future<void> _onUpdatePaymentAccount(
    AndroidUpdatePaymentAccount event,
    Emitter<AndroidPaymentAccountState> emit,
  ) async {
    try {
      emit(AndroidPaymentAccountOperating());
      await _repository.updatePaymentAccount(
        event.organizationId,
        event.accountId,
        event.account,
        event.userId,
      );
      emit(AndroidPaymentAccountOperationSuccess('Payment account updated successfully'));
    } catch (e) {
      emit(AndroidPaymentAccountError('Failed to update account: $e'));
    }
  }

  Future<void> _onDeletePaymentAccount(
    AndroidDeletePaymentAccount event,
    Emitter<AndroidPaymentAccountState> emit,
  ) async {
    try {
      emit(AndroidPaymentAccountOperating());
      await _repository.deletePaymentAccount(event.organizationId, event.accountId);
      emit(AndroidPaymentAccountOperationSuccess('Payment account deleted successfully'));
    } catch (e) {
      emit(AndroidPaymentAccountError('Failed to delete account: $e'));
    }
  }
}

