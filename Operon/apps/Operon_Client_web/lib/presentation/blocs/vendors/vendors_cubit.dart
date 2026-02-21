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
  bool _isSubscribed = false;
  Timer? _searchDebounce;
  int _searchToken = 0;

  String get organizationId => _organizationId;

  void _subscribeToVendors({bool force = false}) {
    if (_isSubscribed && !force) {
      return;
    }
    emit(state.copyWith(status: ViewStatus.loading));
    _vendorsSubscription?.cancel();
    _vendorsSubscription = _repository.watchVendors(_organizationId).listen(
      (vendors) {
        debugPrint('[VendorsCubit] Received ${vendors.length} vendors (stream update)');
        emit(state.copyWith(
          status: ViewStatus.success,
          vendors: vendors,
          filteredVendors: state.searchQuery.isNotEmpty
              ? state.filteredVendors
              : _applyCurrentFilters(vendors),
          message: null,
        ));
        _isSubscribed = true;
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
          .where((v) => v.hasVendorType(state.selectedVendorType!))
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

  Future<void> loadVendors({bool force = false}) async {
    // Re-subscribe only when explicitly forced (retry/refresh)
    _subscribeToVendors(force: force);
  }

  @override
  Future<void> close() {
    _vendorsSubscription?.cancel();
    _isSubscribed = false;
    _searchDebounce?.cancel();
    return super.close();
  }

  void searchVendorsDebounced(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      searchVendors(query);
    });
  }

  Future<void> searchVendors(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(
        searchQuery: '',
        status: ViewStatus.success,
        filteredVendors: _applyCurrentFilters(state.vendors),
      ));
      return;
    }

    emit(state.copyWith(
      searchQuery: trimmed,
      status: ViewStatus.loading,
    ));

    final token = ++_searchToken;
    try {
      final results = await _repository.searchVendors(_organizationId, trimmed);
      if (token != _searchToken) {
        return;
      }
      emit(state.copyWith(
        status: ViewStatus.success,
        filteredVendors: _applyCurrentFilters(results),
        message: null,
      ));
    } catch (e) {
      if (token != _searchToken) {
        return;
      }
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Failed to search vendors: ${e.toString()}',
      ));
    }
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

