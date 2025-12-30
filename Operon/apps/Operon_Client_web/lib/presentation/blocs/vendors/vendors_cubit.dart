import 'dart:async';
import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'vendors_state.dart';

class VendorsCubit extends Cubit<VendorsState> {
  VendorsCubit({
    required VendorsRepository repository,
    required String organizationId,
  })  : _repository = repository,
        _organizationId = organizationId,
        super(const VendorsState()) {
    _subscribeToVendors();
  }

  final VendorsRepository _repository;
  final String _organizationId;
  StreamSubscription<List<Vendor>>? _vendorsSubscription;

  String get organizationId => _organizationId;

  void _subscribeToVendors() {
    emit(state.copyWith(status: ViewStatus.loading));
    _vendorsSubscription?.cancel();
    _vendorsSubscription = _repository.watchVendors(_organizationId).listen(
      (vendors) {
        debugPrint('[VendorsCubit] Received ${vendors.length} vendors (stream update)');
        emit(state.copyWith(
          status: ViewStatus.success,
          vendors: vendors,
          filteredVendors: _applyCurrentFilters(vendors),
          message: null,
        ));
      },
      onError: (e, stackTrace) {
        debugPrint('[VendorsCubit] Error in stream: $e');
        debugPrint('[VendorsCubit] Stack trace: $stackTrace');
        emit(state.copyWith(
          status: ViewStatus.failure,
          message: 'Failed to load vendors: ${e.toString()}',
        ));
      },
    );
  }

  List<Vendor> _applyCurrentFilters(List<Vendor> vendors) {
    var filtered = List<Vendor>.from(vendors);

    // Apply search filter
    if (state.searchQuery.isNotEmpty) {
      final queryLower = state.searchQuery.toLowerCase();
      filtered = filtered.where((v) {
        return v.name.toLowerCase().contains(queryLower) ||
            v.phoneNumber.contains(state.searchQuery) ||
            (v.gstNumber?.toLowerCase().contains(queryLower) ?? false);
      }).toList();
    }

    // Apply type filter
    if (state.selectedVendorType != null) {
      filtered = filtered
          .where((v) => v.vendorType == state.selectedVendorType)
          .toList();
    }

    // Apply status filter
    if (state.selectedStatus != null) {
      filtered = filtered
          .where((v) => v.status == state.selectedStatus)
          .toList();
    }

    return filtered;
  }

  Future<void> loadVendors() async {
    // Re-subscribe to refresh data
    _subscribeToVendors();
  }

  @override
  Future<void> close() {
    _vendorsSubscription?.cancel();
    return super.close();
  }

  void searchVendors(String query) {
    // Apply search filter to current vendors (client-side filtering)
    emit(state.copyWith(
      searchQuery: query,
      filteredVendors: _applyCurrentFilters(state.vendors),
    ));
  }

  void filterByType(VendorType? vendorType) {
    // Apply type filter to current vendors (client-side filtering)
    emit(state.copyWith(
      selectedVendorType: vendorType,
      filteredVendors: _applyCurrentFilters(state.vendors),
    ));
  }

  void filterByStatus(VendorStatus? status) {
    // Apply status filter to current vendors (client-side filtering)
    emit(state.copyWith(
      selectedStatus: status,
      filteredVendors: _applyCurrentFilters(state.vendors),
    ));
  }

  Future<void> createVendor(Vendor vendor) async {
    try {
      await _repository.createVendor(vendor);
      // Stream will auto-update, no manual refresh needed
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to create vendor: ${e.toString()}',
      ));
    }
  }

  Future<void> updateVendor(Vendor vendor) async {
    try {
      await _repository.updateVendor(vendor);
      // Stream will auto-update, no manual refresh needed
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to update vendor: ${e.toString()}',
      ));
    }
  }

  Future<void> deleteVendor(String vendorId) async {
    // Check balance before deleting
    final vendor = state.vendors.firstWhere(
      (v) => v.id == vendorId,
      orElse: () => throw Exception('Vendor not found'),
    );

    if (vendor.currentBalance != 0) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Cannot delete vendor with pending balance. Current balance: ₹${vendor.currentBalance.toStringAsFixed(2)}',
      ));
      return;
    }

    try {
      await _repository.deleteVendor(vendorId);
      // Stream will auto-update, no manual refresh needed
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to delete vendor: ${e.toString()}',
      ));
    }
  }
}

