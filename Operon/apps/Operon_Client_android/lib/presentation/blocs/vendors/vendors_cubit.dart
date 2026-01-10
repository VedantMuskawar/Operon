import 'package:core_bloc/core_bloc.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_models/core_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'vendors_state.dart';

class VendorsCubit extends Cubit<VendorsState> {
  VendorsCubit({
    required VendorsRepository repository,
    required String organizationId,
    required bool canCreate,
    required bool canEdit,
    required bool canDelete,
  })  : _repository = repository,
        _organizationId = organizationId,
        _canCreate = canCreate,
        _canEdit = canEdit,
        _canDelete = canDelete,
        super(const VendorsState());

  final VendorsRepository _repository;
  final String _organizationId;
  final bool _canCreate;
  final bool _canEdit;
  final bool _canDelete;

  bool get canCreate => _canCreate;
  bool get canEdit => _canEdit;
  bool get canDelete => _canDelete;
  String get organizationId => _organizationId;

  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      final vendors = await _repository.fetchVendors(_organizationId);
      emit(
        state.copyWith(
          status: ViewStatus.success,
          vendors: vendors,
          filteredVendors: vendors,
        ),
      );
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to load vendors: $e',
      ));
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      // Reset to all vendors
      _applyFilters();
      return;
    }

    emit(state.copyWith(
      status: ViewStatus.loading,
      searchQuery: query,
      message: null,
    ));

    try {
      final results = await _repository.searchVendors(_organizationId, query);
      emit(state.copyWith(
        status: ViewStatus.success,
        filteredVendors: results,
        searchQuery: query,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Search failed: $e',
      ));
    }
  }

  Future<void> filterByType(VendorType? vendorType) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      selectedVendorType: vendorType,
      message: null,
    ));

    try {
      final vendors = await _repository.filterVendorsByType(
        _organizationId,
        vendorType,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        filteredVendors: vendors,
        selectedVendorType: vendorType,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Filter failed: $e',
      ));
    }
  }

  Future<void> filterByStatus(VendorStatus? status) async {
    emit(state.copyWith(
      status: ViewStatus.loading,
      selectedStatus: status,
      message: null,
    ));

    try {
      final vendors = await _repository.filterVendorsByStatus(
        _organizationId,
        status,
      );
      emit(state.copyWith(
        status: ViewStatus.success,
        filteredVendors: vendors,
        selectedStatus: status,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Filter failed: $e',
      ));
    }
  }

  void _applyFilters() {
    // Apply current filters to all vendors
    var filtered = state.vendors;

    if (state.selectedVendorType != null) {
      filtered = filtered
          .where((v) => v.vendorType == state.selectedVendorType)
          .toList();
    }

    if (state.selectedStatus != null) {
      filtered = filtered
          .where((v) => v.status == state.selectedStatus)
          .toList();
    }

    emit(state.copyWith(
      filteredVendors: filtered,
      searchQuery: '',
    ));
  }

  Future<void> createVendor(Vendor vendor) async {
    if (!_canCreate) return;
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.createVendor(vendor);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to create vendor: $e',
      ));
    }
  }

  Future<void> updateVendor(Vendor vendor) async {
    if (!_canEdit) return;
    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.updateVendor(vendor);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to update vendor: $e',
      ));
    }
  }

  Future<void> deleteVendor(String vendorId) async {
    if (!_canDelete) return;
    
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

    emit(state.copyWith(status: ViewStatus.loading, message: null));
    try {
      await _repository.deleteVendor(vendorId);
      await load();
    } catch (e) {
      emit(state.copyWith(
        status: ViewStatus.failure,
        message: 'Unable to delete vendor: $e',
      ));
    }
  }
}









