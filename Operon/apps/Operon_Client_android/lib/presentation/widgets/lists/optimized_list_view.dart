import 'package:flutter/material.dart';
import 'package:dash_mobile/presentation/widgets/error/error_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/empty/empty_state_widget.dart';
import 'package:dash_mobile/presentation/widgets/loading/loading_skeleton.dart';

/// Wrapper around ListView.builder with built-in error/loading/empty states
/// and pull-to-refresh functionality
class OptimizedListView<T> extends StatelessWidget {
  const OptimizedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.onRefresh,
    this.isEmpty = false,
    this.isLoading = false,
    this.error,
    this.onRetry,
    this.emptyStateIcon = Icons.inbox,
    this.emptyStateTitle = 'No items',
    this.emptyStateMessage = 'No items to display',
    this.emptyStateActionLabel,
    this.onEmptyStateAction,
    this.itemExtent,
    this.separatorBuilder,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  final List<T> items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Future<void> Function()? onRefresh;
  final bool isEmpty;
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;
  final IconData emptyStateIcon;
  final String emptyStateTitle;
  final String emptyStateMessage;
  final String? emptyStateActionLabel;
  final VoidCallback? onEmptyStateAction;
  final double? itemExtent;
  final Widget Function(BuildContext, int)? separatorBuilder;
  final EdgeInsets? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    // Error state
    if (error != null && !isLoading) {
      return ErrorStateWidget(
        message: error!,
        errorType: error!.toLowerCase().contains('network') ||
                error!.toLowerCase().contains('internet')
            ? ErrorType.network
            : ErrorType.generic,
        onRetry: onRetry,
      );
    }

    // Loading state
    if (isLoading && items.isEmpty) {
      return _buildLoadingState();
    }

    // Empty state
    if (isEmpty && !isLoading) {
      return EmptyStateWidget(
        icon: emptyStateIcon,
        title: emptyStateTitle,
        message: emptyStateMessage,
        actionLabel: emptyStateActionLabel,
        onAction: onEmptyStateAction,
      );
    }

    // List view
    Widget listView;
    if (separatorBuilder != null) {
      listView = ListView.separated(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemCount: items.length,
        separatorBuilder: separatorBuilder!,
        itemBuilder: (context, index) {
          return itemBuilder(context, items[index], index);
        },
      );
    } else {
      listView = ListView.builder(
        shrinkWrap: shrinkWrap,
        physics: physics,
        padding: padding,
        itemExtent: itemExtent,
        itemCount: items.length,
        itemBuilder: (context, index) {
          return itemBuilder(context, items[index], index);
        },
      );
    }

    // Wrap with pull-to-refresh if callback provided
    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: const Color(0xFF6F4BFF),
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildLoadingState() {
    // Default skeleton loading
    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding,
      itemExtent: itemExtent ?? 80,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const LoadingSkeleton(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const LoadingSkeleton(width: 150, height: 16),
                      const SizedBox(height: 8),
                      const LoadingSkeleton(width: 100, height: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

