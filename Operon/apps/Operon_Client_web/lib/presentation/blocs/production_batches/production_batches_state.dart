import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

class ProductionBatchesState extends BaseState {
  const ProductionBatchesState({
    super.status = ViewStatus.initial,
    this.batches = const [],
    super.message,
    this.selectedStatus,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.selectedBatch,
  });

  final List<ProductionBatch> batches;
  final ProductionBatchStatus? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final ProductionBatch? selectedBatch;

  List<ProductionBatch> get filteredBatches {
    var filtered = batches;

    if (selectedStatus != null) {
      filtered = filtered.where((b) => b.status == selectedStatus).toList();
    }

    if (startDate != null) {
      filtered = filtered.where((b) => b.batchDate.isAfter(startDate!) || 
          b.batchDate.isAtSameMomentAs(startDate!)).toList();
    }

    if (endDate != null) {
      final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      filtered = filtered.where((b) => b.batchDate.isBefore(endOfDay) || 
          b.batchDate.isAtSameMomentAs(endOfDay)).toList();
    }

    if (searchQuery != null && searchQuery!.isNotEmpty) {
      final query = searchQuery!.toLowerCase();
      filtered = filtered.where((b) {
        return b.batchId.toLowerCase().contains(query) ||
            (b.employeeNames?.any((name) => name.toLowerCase().contains(query)) ?? false) ||
            (b.productName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  @override
  ProductionBatchesState copyWith({
    ViewStatus? status,
    List<ProductionBatch>? batches,
    String? message,
    ProductionBatchStatus? selectedStatus,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    ProductionBatch? selectedBatch,
  }) {
    return ProductionBatchesState(
      status: status ?? this.status,
      batches: batches ?? this.batches,
      message: message,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedBatch: selectedBatch ?? this.selectedBatch,
    );
  }
}

