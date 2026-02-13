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
  factory ProductionBatchesState({
    ViewStatus status = ViewStatus.initial,
    List<ProductionBatch> batches = const [],
    String? message,
    ProductionBatchStatus? selectedStatus,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? startDate2,
    DateTime? endDate2,
    String? searchQuery,
    ProductionBatch? selectedBatch,
    WorkflowTab selectedTab = WorkflowTab.all,
    List<ProductionBatch>? filteredBatches,
    int? totalBatches,
    int? pendingCalculations,
    int? pendingApprovals,
    int? processedToday,
    double? totalWagesProcessed,
    int? needsActionCount,
  }) {
    final computedStats = _computeStats(batches);
    return ProductionBatchesState._internal(
      status: status,
      message: message,
      batches: batches,
      selectedStatus: selectedStatus,
      startDate: startDate,
      endDate: endDate,
      startDate2: startDate2,
      endDate2: endDate2,
      searchQuery: searchQuery,
      selectedBatch: selectedBatch,
      selectedTab: selectedTab,
      filteredBatches: filteredBatches ??
          _computeFilteredBatches(
            batches: batches,
            selectedTab: selectedTab,
            startDate: startDate,
            endDate: endDate,
            searchQuery: searchQuery,
          ),
      totalBatches: totalBatches ?? batches.length,
      pendingCalculations:
          pendingCalculations ?? computedStats.pendingCalculations,
      pendingApprovals: pendingApprovals ?? computedStats.pendingApprovals,
      processedToday: processedToday ?? computedStats.processedToday,
      totalWagesProcessed:
          totalWagesProcessed ?? computedStats.totalWagesProcessed,
      needsActionCount: needsActionCount ?? computedStats.needsActionCount,
    );
  }

  const ProductionBatchesState._internal({
    required ViewStatus status,
    String? message,
    required this.batches,
    required this.selectedStatus,
    required this.startDate,
    required this.endDate,
    required this.startDate2,
    required this.endDate2,
    required this.searchQuery,
    required this.selectedBatch,
    required this.selectedTab,
    required this.filteredBatches,
    required this.totalBatches,
    required this.pendingCalculations,
    required this.pendingApprovals,
    required this.processedToday,
    required this.totalWagesProcessed,
    required this.needsActionCount,
  }) : super(status: status, message: message);

  final List<ProductionBatch> batches;
  final List<ProductionBatch> filteredBatches;
  final ProductionBatchStatus? selectedStatus;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? startDate2;
  final DateTime? endDate2;
  final String? searchQuery;
  final ProductionBatch? selectedBatch;
  final WorkflowTab selectedTab;
  final int totalBatches;
  final int pendingCalculations;
  final int pendingApprovals;
  final int processedToday;
  final double totalWagesProcessed;
  final int needsActionCount;

  static List<ProductionBatch> _computeFilteredBatches({
    required List<ProductionBatch> batches,
    required WorkflowTab selectedTab,
    required DateTime? startDate,
    required DateTime? endDate,
    required String? searchQuery,
  }) {
    var filtered = batches;

    switch (selectedTab) {
      case WorkflowTab.all:
        break;
      case WorkflowTab.needsAction:
        filtered = filtered
            .where((b) =>
                b.status == ProductionBatchStatus.recorded ||
                b.status == ProductionBatchStatus.calculated)
            .toList();
        break;
      case WorkflowTab.recorded:
        filtered = filtered
            .where((b) => b.status == ProductionBatchStatus.recorded)
            .toList();
        break;
      case WorkflowTab.calculated:
        filtered = filtered
            .where((b) => b.status == ProductionBatchStatus.calculated)
            .toList();
        break;
      case WorkflowTab.approved:
        filtered = filtered
            .where((b) => b.status == ProductionBatchStatus.approved)
            .toList();
        break;
      case WorkflowTab.processed:
        filtered = filtered
            .where((b) => b.status == ProductionBatchStatus.processed)
            .toList();
        break;
    }

    if (startDate != null) {
      filtered = filtered
          .where((b) =>
              b.batchDate.isAfter(startDate) ||
              b.batchDate.isAtSameMomentAs(startDate))
          .toList();
    }

    if (endDate != null) {
      final endOfDay =
          DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
      filtered = filtered
          .where((b) =>
              b.batchDate.isBefore(endOfDay) ||
              b.batchDate.isAtSameMomentAs(endOfDay))
          .toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((b) {
        return b.batchId.toLowerCase().contains(query) ||
            (b.employeeNames
                    ?.any((name) => name.toLowerCase().contains(query)) ??
                false) ||
            (b.productName?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    return filtered;
  }

  static _ProductionBatchStats _computeStats(List<ProductionBatch> batches) {
    var pendingCalculations = 0;
    var pendingApprovals = 0;
    var processedToday = 0;
    var totalWagesProcessed = 0.0;
    var needsActionCount = 0;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    for (final batch in batches) {
      switch (batch.status) {
        case ProductionBatchStatus.recorded:
          pendingCalculations++;
          needsActionCount++;
          break;
        case ProductionBatchStatus.calculated:
          pendingApprovals++;
          needsActionCount++;
          break;
        case ProductionBatchStatus.processed:
          if (batch.updatedAt.isAfter(startOfDay)) {
            processedToday++;
          }
          if (batch.totalWages != null) {
            totalWagesProcessed += batch.totalWages!;
          }
          break;
        case ProductionBatchStatus.approved:
          break;
      }
    }

    return _ProductionBatchStats(
      pendingCalculations: pendingCalculations,
      pendingApprovals: pendingApprovals,
      processedToday: processedToday,
      totalWagesProcessed: totalWagesProcessed,
      needsActionCount: needsActionCount,
    );
  }

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

class _ProductionBatchStats {
  const _ProductionBatchStats({
    required this.pendingCalculations,
    required this.pendingApprovals,
    required this.processedToday,
    required this.totalWagesProcessed,
    required this.needsActionCount,
  });

  final int pendingCalculations;
  final int pendingApprovals;
  final int processedToday;
  final double totalWagesProcessed;
  final int needsActionCount;
}

