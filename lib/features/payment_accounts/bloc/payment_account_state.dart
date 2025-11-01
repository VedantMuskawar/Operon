import 'package:equatable/equatable.dart';
import '../models/payment_account.dart';

abstract class PaymentAccountState extends Equatable {
  const PaymentAccountState();

  @override
  List<Object?> get props => [];
}

// Initial state
class PaymentAccountInitial extends PaymentAccountState {
  const PaymentAccountInitial();
}

// Loading state
class PaymentAccountLoading extends PaymentAccountState {
  const PaymentAccountLoading();
}

// Payment accounts loaded successfully
class PaymentAccountLoaded extends PaymentAccountState {
  final List<PaymentAccount> accounts;
  final String? searchQuery;

  const PaymentAccountLoaded({
    required this.accounts,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [accounts, searchQuery];

  PaymentAccountLoaded copyWith({
    List<PaymentAccount>? accounts,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return PaymentAccountLoaded(
      accounts: accounts ?? this.accounts,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

// Operation in progress (add/update/delete)
class PaymentAccountOperating extends PaymentAccountState {
  const PaymentAccountOperating();
}

// Operation successful
class PaymentAccountOperationSuccess extends PaymentAccountState {
  final String message;

  const PaymentAccountOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error state
class PaymentAccountError extends PaymentAccountState {
  final String message;

  const PaymentAccountError(this.message);

  @override
  List<Object?> get props => [message];
}

// Empty state (no payment accounts found)
class PaymentAccountEmpty extends PaymentAccountState {
  final String? searchQuery;

  const PaymentAccountEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

