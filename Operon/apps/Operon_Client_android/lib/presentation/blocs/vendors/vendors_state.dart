import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class VendorsState extends BaseState {
  const VendorsState({
    super.status = ViewStatus.initial,
    this.vendors = const [],
    this.filteredVendors = const [],
    this.searchQuery = '',
    this.selectedVendorType,
    this.selectedStatus,
    this.message,
  }) : super(message: message);

  final List<Vendor> vendors;
  final List<Vendor> filteredVendors;
  final String searchQuery;
  final VendorType? selectedVendorType;
  final VendorStatus? selectedStatus;
  @override
  final String? message;

  bool get isSearching => searchQuery.isNotEmpty;
  bool get isFiltered => selectedVendorType != null || selectedStatus != null;

  @override
  VendorsState copyWith({
    ViewStatus? status,
    List<Vendor>? vendors,
    List<Vendor>? filteredVendors,
    String? searchQuery,
    VendorType? selectedVendorType,
    VendorStatus? selectedStatus,
    String? message,
  }) {
    return VendorsState(
      status: status ?? this.status,
      vendors: vendors ?? this.vendors,
      filteredVendors: filteredVendors ?? this.filteredVendors,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedVendorType: selectedVendorType ?? this.selectedVendorType,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      message: message ?? this.message,
    );
  }
}


