import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'address_event.dart';
import 'address_state.dart';
import '../repositories/address_repository.dart';
import '../models/address.dart';

class AddressBloc extends Bloc<AddressEvent, AddressState> {
  final AddressRepository _addressRepository;

  AddressBloc({required AddressRepository addressRepository})
      : _addressRepository = addressRepository,
        super(const AddressInitial()) {
    on<LoadAddresses>(_onLoadAddresses);
    on<AddAddress>(_onAddAddress);
    on<UpdateAddress>(_onUpdateAddress);
    on<DeleteAddress>(_onDeleteAddress);
    on<SearchAddresses>(_onSearchAddresses);
    on<ResetAddressSearch>(_onResetSearch);
    on<RefreshAddresses>(_onRefreshAddresses);
  }

  Future<void> _onLoadAddresses(
    LoadAddresses event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressLoading());

      await emit.forEach(
        _addressRepository.getAddressesStream(event.organizationId),
        onData: (List<Address> addresses) {
          if (addresses.isEmpty) {
            return const AddressEmpty();
          }
          return AddressLoaded(addresses: addresses);
        },
        onError: (error, stackTrace) {
          return AddressError('Failed to load addresses: $error');
        },
      );
    } catch (e) {
      emit(AddressError('Failed to load addresses: $e'));
    }
  }

  Future<void> _onAddAddress(
    AddAddress event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressOperating());

      await _addressRepository.addAddress(
        event.organizationId,
        event.address,
        event.userId,
      );

      emit(const AddressOperationSuccess('Address added successfully'));
    } catch (e) {
      emit(AddressError('Failed to add address: $e'));
    }
  }

  Future<void> _onUpdateAddress(
    UpdateAddress event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressOperating());

      await _addressRepository.updateAddress(
        event.organizationId,
        event.addressId,
        event.address,
        event.userId,
      );

      emit(const AddressOperationSuccess('Address updated successfully'));
    } catch (e) {
      emit(AddressError('Failed to update address: $e'));
    }
  }

  Future<void> _onDeleteAddress(
    DeleteAddress event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressOperating());

      await _addressRepository.deleteAddress(
        event.organizationId,
        event.addressId,
      );

      emit(const AddressOperationSuccess('Address deleted successfully'));
    } catch (e) {
      emit(AddressError('Failed to delete address: $e'));
    }
  }

  Future<void> _onSearchAddresses(
    SearchAddresses event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressLoading());

      await emit.forEach(
        _addressRepository.searchAddresses(
          event.organizationId,
          event.query,
        ),
        onData: (List<Address> addresses) {
          if (addresses.isEmpty && event.query.isNotEmpty) {
            return AddressEmpty(searchQuery: event.query);
          } else if (addresses.isEmpty) {
            return const AddressEmpty();
          }
          return AddressLoaded(addresses: addresses, searchQuery: event.query);
        },
        onError: (error, stackTrace) {
          return AddressError('Failed to search addresses: $error');
        },
      );
    } catch (e) {
      emit(AddressError('Failed to search addresses: $e'));
    }
  }

  void _onResetSearch(
    ResetAddressSearch event,
    Emitter<AddressState> emit,
  ) {
    if (state is AddressLoaded) {
      final currentState = state as AddressLoaded;
      emit(currentState.copyWith(searchQueryReset: () => null));
    }
  }

  Future<void> _onRefreshAddresses(
    RefreshAddresses event,
    Emitter<AddressState> emit,
  ) async {
    try {
      emit(const AddressLoading());

      final addresses = await _addressRepository.getAddresses(
        event.organizationId,
      );

      if (addresses.isEmpty) {
        emit(const AddressEmpty());
      } else {
        emit(AddressLoaded(addresses: addresses));
      }
    } catch (e) {
      emit(AddressError('Failed to refresh addresses: $e'));
    }
  }
}

