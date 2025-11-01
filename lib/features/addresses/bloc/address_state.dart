import 'package:equatable/equatable.dart';
import '../models/address.dart';

abstract class AddressState extends Equatable {
  const AddressState();

  @override
  List<Object?> get props => [];
}

// Initial state
class AddressInitial extends AddressState {
  const AddressInitial();
}

// Loading state
class AddressLoading extends AddressState {
  const AddressLoading();
}

// Addresses loaded successfully
class AddressLoaded extends AddressState {
  final List<Address> addresses;
  final String? searchQuery;

  const AddressLoaded({
    required this.addresses,
    this.searchQuery,
  });

  @override
  List<Object?> get props => [addresses, searchQuery];

  AddressLoaded copyWith({
    List<Address>? addresses,
    String? searchQuery,
    String? Function()? searchQueryReset,
  }) {
    return AddressLoaded(
      addresses: addresses ?? this.addresses,
      searchQuery: searchQueryReset != null ? null : (searchQuery ?? this.searchQuery),
    );
  }
}

// Operation in progress (add/update/delete)
class AddressOperating extends AddressState {
  const AddressOperating();
}

// Operation successful
class AddressOperationSuccess extends AddressState {
  final String message;

  const AddressOperationSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Error state
class AddressError extends AddressState {
  final String message;

  const AddressError(this.message);

  @override
  List<Object?> get props => [message];
}

// Empty state (no addresses found)
class AddressEmpty extends AddressState {
  final String? searchQuery;

  const AddressEmpty({this.searchQuery});

  @override
  List<Object?> get props => [searchQuery];
}

