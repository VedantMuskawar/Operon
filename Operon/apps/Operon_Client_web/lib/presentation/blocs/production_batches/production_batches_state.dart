import 'package:core_bloc/core_bloc.dart';
import 'package:core_models/core_models.dart';

enum WorkflowTab {
  all,
  needsAction,
  recorded,
  calculated,
  approved,
  processed,
}

class ProductionBatchesState extends BaseState {
  const ProductionBatchesState({
    super.status = ViewStatus.initial,
    this.batches = const [],
    super.message,
    this.selectedStatus,
    this.startDate,
    this.endDate,
    this.startDate2,
    this.endDate2,
    this.searchQuery,
    this.selectedBatch,
    this.selectedTab = WorkflowTab.all,
  });

  final List<ProductionBatch> batches;
  final ProductionBatchStatus? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? startDate2;
  final DateTime? endDate2;
  final String? searchQuery;
  final ProductionBatch? selectedBatch;
  final WorkflowTab selectedTab;

  List<ProductionBatch> get filteredBatches {
    var filtered = batches;

    // Apply workflow tab filter
    switch (selectedTab) {
      case WorkflowTab.all:
        // Show all batches
        break;
      case WorkflowTab.needsAction:
        // Show batches that need calculation or approval
        filtered = filtered.where((b) =>
            b.status == ProductionBatchStatus.recorded ||
            b.status == ProductionBatchStatus.calculated).toList();
        break;
      case WorkflowTab.recorded:
        filtered = filtered.where((b) => b.status == ProductionBatchStatus.recorded).toList();
        break;
      case WorkflowTab.calculated:
        filtered = filtered.where((b) => b.status == ProductionBatchStatus.calculated).toList();
        break;
      case WorkflowTab.approved:
        filtered = filtered.where((b) => b.status == ProductionBatchStatus.approved).toList();
        break;
      case WorkflowTab.processed:
        filtered = filtered.where((b) => b.status == ProductionBatchStatus.processed).toList();
        break;
    }

    // Apply date range filter
    if (startDate != null) {
      filtered = filtered.where((b) => b.batchDate.isAfter(startDate!) || 
          b.batchDate.isAtSameMomentAs(startDate!)).toList();
    }

    if (endDate != null) {
      final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
      filtered = filtered.where((b) => b.batchDate.isBefore(endOfDay) || 
          b.batchDate.isAtSameMomentAs(endOfDay)).toList();
    }

    // Apply search query filter
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

  // Statistics getters
  int get totalBatches => batches.length;

  int get pendingCalculations => batches.where((b) => 
      b.status == ProductionBatchStatus.recorded).length;

  int get pendingApprovals => batches.where((b) => 
      b.status == ProductionBatchStatus.calculated).length;

  int get processedToday {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return batches.where((b) => 
        b.status == ProductionBatchStatus.processed &&
        b.updatedAt.isAfter(startOfDay)).length;
  }

  double get totalWagesProcessed {
    return batches.where((b) => 
        b.status == ProductionBatchStatus.processed && 
        b.totalWages != null)
        .fold(0.0, (sum, b) => sum + (b.totalWages ?? 0.0));
  }

  int get needsActionCount => batches.where((b) =>
      b.status == ProductionBatchStatus.recorded ||
      b.status == ProductionBatchStatus.calculated).length;

  @override
  ProductionBatchesState copyWith({
    ViewStatus? status,
    List<ProductionBatch>? batches,
    String? message,
    ProductionBatchStatus? selectedStatus,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? startDate2,
    DateTime? endDate2,
    String? searchQuery,
    ProductionBatch? selectedBatch,
    WorkflowTab? selectedTab,
  }) {
    return ProductionBatchesState(
      status: status ?? this.status,
      batches: batches ?? this.batches,
      message: message,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      startDate2: startDate2 ?? this.startDate2,
      endDate2: endDate2 ?? this.endDate2,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedBatch: selectedBatch ?? this.selectedBatch,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}

