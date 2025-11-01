import 'package:equatable/equatable.dart';
import '../models/payment_account.dart';

abstract class PaymentAccountEvent extends Equatable {
  const PaymentAccountEvent();

  @override
  List<Object?> get props => [];
}

// Load payment accounts for an organization
class LoadPaymentAccounts extends PaymentAccountEvent {
  final String organizationId;

  const LoadPaymentAccounts(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Add a new payment account
class AddPaymentAccount extends PaymentAccountEvent {
  final String organizationId;
  final PaymentAccount account;
  final String userId;

  const AddPaymentAccount({
    required this.organizationId,
    required this.account,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, account, userId];
}

// Update an existing payment account
class UpdatePaymentAccount extends PaymentAccountEvent {
  final String organizationId;
  final String accountId;
  final PaymentAccount account;
  final String userId;

  const UpdatePaymentAccount({
    required this.organizationId,
    required this.accountId,
    required this.account,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, accountId, account, userId];
}

// Delete a payment account
class DeletePaymentAccount extends PaymentAccountEvent {
  final String organizationId;
  final String accountId;

  const DeletePaymentAccount({
    required this.organizationId,
    required this.accountId,
  });

  @override
  List<Object?> get props => [organizationId, accountId];
}

// Search payment accounts
class SearchPaymentAccounts extends PaymentAccountEvent {
  final String organizationId;
  final String query;

  const SearchPaymentAccounts({
    required this.organizationId,
    required this.query,
  });

  @override
  List<Object?> get props => [organizationId, query];
}

// Reset search
class ResetSearch extends PaymentAccountEvent {
  const ResetSearch();
}

// Refresh payment accounts
class RefreshPaymentAccounts extends PaymentAccountEvent {
  final String organizationId;

  const RefreshPaymentAccounts(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Set default account
class SetDefaultAccount extends PaymentAccountEvent {
  final String organizationId;
  final String accountId;

  const SetDefaultAccount({
    required this.organizationId,
    required this.accountId,
  });

  @override
  List<Object?> get props => [organizationId, accountId];
}

