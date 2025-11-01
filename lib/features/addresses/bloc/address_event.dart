import 'package:equatable/equatable.dart';
import '../models/address.dart';

abstract class AddressEvent extends Equatable {
  const AddressEvent();

  @override
  List<Object?> get props => [];
}

// Load addresses for an organization
class LoadAddresses extends AddressEvent {
  final String organizationId;

  const LoadAddresses(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

// Add a new address
class AddAddress extends AddressEvent {
  final String organizationId;
  final Address address;
  final String userId;

  const AddAddress({
    required this.organizationId,
    required this.address,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, address, userId];
}

// Update an existing address
class UpdateAddress extends AddressEvent {
  final String organizationId;
  final String addressId;
  final Address address;
  final String userId;

  const UpdateAddress({
    required this.organizationId,
    required this.addressId,
    required this.address,
    required this.userId,
  });

  @override
  List<Object?> get props => [organizationId, addressId, address, userId];
}

// Delete an address
class DeleteAddress extends AddressEvent {
  final String organizationId;
  final String addressId;

  const DeleteAddress({
    required this.organizationId,
    required this.addressId,
  });

  @override
  List<Object?> get props => [organizationId, addressId];
}

// Search addresses
class SearchAddresses extends AddressEvent {
  final String organizationId;
  final String query;

  const SearchAddresses({
    required this.organizationId,
    required this.query,
  });

  @override
  List<Object?> get props => [organizationId, query];
}

// Reset search
class ResetAddressSearch extends AddressEvent {
  const ResetAddressSearch();
}

// Refresh addresses
class RefreshAddresses extends AddressEvent {
  final String organizationId;

  const RefreshAddresses(this.organizationId);

  @override
  List<Object?> get props => [organizationId];
}

