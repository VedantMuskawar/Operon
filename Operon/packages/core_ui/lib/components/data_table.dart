import 'package:flutter/material.dart';
import 'package:core_ui/theme/auth_colors.dart';

/// Column definition for DataTable
class DataTableColumn<T> {
  const DataTableColumn({
    required this.label,
    this.icon,
    this.width,
    this.flex,
    this.alignment = Alignment.centerLeft,
    this.numeric = false,
    this.cellBuilder,
  });

  /// Column header label
  final String label;

  /// Optional icon for column header
  final IconData? icon;

  /// Fixed width for the column (if null, uses flex)
  final double? width;

  /// Flex value for column width (used when width is null)
  final int? flex;

  /// Text alignment for column content
  final Alignment alignment;

  /// Whether this column contains numeric data
  final bool numeric;

  /// Custom cell builder (if null, uses toString() on the value)
  final Widget Function(BuildContext context, T row, int rowIndex)? cellBuilder;
}

/// Row action definition
class DataTableRowAction<T> {
  const DataTableRowAction({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final void Function(T row, int rowIndex) onTap;
  final String? tooltip;
  final Color? color;
}

/// Reusable DataTable component with modern styling
/// Can be used to replace list views across the app
class DataTable<T> extends StatelessWidget {
  const DataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.rowActions,
    this.onRowTap,
    this.rowKeyBuilder,
    this.emptyStateMessage = 'No data available',
    this.emptyStateIcon = Icons.inbox_outlined,
    this.showHeader = true,
    this.borderRadius = 12,
    this.headerBackgroundColor,
    this.rowBackgroundColor,
    this.rowBackgroundColorBuilder,
    this.hoverColor,
    this.stickyHeader = false,
  });

  /// Column definitions
  final List<DataTableColumn<T>> columns;

  /// Data rows
  final List<T> rows;

  /// Optional row actions (displayed in a separate column)
  final List<DataTableRowAction<T>>? rowActions;

  /// Callback when a row is tapped
  final void Function(T row, int index)? onRowTap;

  /// Optional key builder for rows (improves row-level rebuilds)
  final Key? Function(T row, int index)? rowKeyBuilder;

  /// Message to show when table is empty
  final String emptyStateMessage;

  /// Icon to show when table is empty
  final IconData emptyStateIcon;

  /// Whether to show the header row
  final bool showHeader;

  /// Border radius for the table container
  final double borderRadius;

  /// Background color for header row
  final Color? headerBackgroundColor;

  /// Background color for data rows (used when rowBackgroundColorBuilder is null)
  final Color? rowBackgroundColor;

  /// Optional per-row background color (overrides rowBackgroundColor when set)
  final Color? Function(T row, int index)? rowBackgroundColorBuilder;

  /// Background color when row is hovered
  final Color? hoverColor;

  /// Whether header should be sticky (stays visible when scrolling)
  final bool stickyHeader;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyState(
        message: emptyStateMessage,
        icon: emptyStateIcon,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: AuthColors.textMainWithOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHeader) ...[
                _TableHeader(
                  columns: columns,
                  rowActions: rowActions,
                  backgroundColor: headerBackgroundColor ?? AuthColors.textMainWithOpacity(0.15),
                ),
                Divider(
                  height: 1,
                  color: AuthColors.textMainWithOpacity(0.12),
                ),
              ],
              // When height is bounded, use scrollable ListView to virtualize rows; otherwise shrinkWrap
              if (constraints.maxHeight.isFinite)
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: AuthColors.textMainWithOpacity(0.12),
                    ),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final isEven = index % 2 == 0;
                      final defaultBg = isEven
                          ? Colors.transparent
                          : AuthColors.textMainWithOpacity(0.03);
                      return RepaintBoundary(
                        child: _TableRow<T>(
                          key: rowKeyBuilder?.call(row, index),
                          row: row,
                          rowIndex: index,
                          columns: columns,
                          rowActions: rowActions,
                          onTap: onRowTap != null
                              ? () => onRowTap!(row, index)
                              : null,
                          backgroundColor: rowBackgroundColorBuilder != null
                              ? (rowBackgroundColorBuilder!(row, index) ?? defaultBg)
                              : (rowBackgroundColor ?? defaultBg),
                          hoverColor: hoverColor,
                        ),
                      );
                    },
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: AuthColors.textMainWithOpacity(0.12),
                  ),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final isEven = index % 2 == 0;
                    final defaultBg = isEven
                        ? Colors.transparent
                        : AuthColors.textMainWithOpacity(0.03);
                    return RepaintBoundary(
                      child: _TableRow<T>(
                        key: rowKeyBuilder?.call(row, index),
                        row: row,
                        rowIndex: index,
                        columns: columns,
                        rowActions: rowActions,
                        onTap: onRowTap != null
                            ? () => onRowTap!(row, index)
                            : null,
                        backgroundColor: rowBackgroundColorBuilder != null
                            ? (rowBackgroundColorBuilder!(row, index) ?? defaultBg)
                            : (rowBackgroundColor ?? defaultBg),
                        hoverColor: hoverColor,
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TableHeader<T> extends StatelessWidget {
  const _TableHeader({
    required this.columns,
    this.rowActions,
    this.backgroundColor,
  });

  final List<DataTableColumn<T>> columns;
  final List<DataTableRowAction<T>>? rowActions;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? AuthColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          ...columns.map((column) {
            final width = column.width;
            final flex = column.flex ?? 1;
            
            Widget child = Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (column.icon != null) ...[
                  Icon(
                    column.icon,
                    size: 16,
                    color: AuthColors.textMain,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  column.label,
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            );

            if (width != null) {
              return SizedBox(
                width: width,
                child: Center(child: child),
              );
            } else {
              return Expanded(
                flex: flex,
                child: Center(child: child),
              );
            }
          }),
          if (rowActions != null && rowActions!.isNotEmpty) ...[
            const SizedBox(width: 16),
            SizedBox(
              width: (rowActions!.length * 52).toDouble(),
              child: const Center(
                child: Text(
                  'Actions',
                  style: TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro Display',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TableRow<T> extends StatefulWidget {
  const _TableRow({
    super.key,
    required this.row,
    required this.rowIndex,
    required this.columns,
    this.rowActions,
    this.onTap,
    this.backgroundColor,
    this.hoverColor,
  });

  final T row;
  final int rowIndex;
  final List<DataTableColumn<T>> columns;
  final List<DataTableRowAction<T>>? rowActions;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? hoverColor;

  @override
  State<_TableRow<T>> createState() => _TableRowState<T>();
}

class _TableRowState<T> extends State<_TableRow<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _isHovered
              ? (widget.hoverColor ?? AuthColors.textMainWithOpacity(0.05))
              : (widget.backgroundColor ?? Colors.transparent),
          child: Row(
            children: [
              ...widget.columns.map((column) {
                final width = column.width;
                final flex = column.flex ?? 1;

                Widget cell;
                if (column.cellBuilder != null) {
                  cell = column.cellBuilder!(context, widget.row, widget.rowIndex);
                } else {
                  cell = Text(
                    widget.row.toString(),
                    style: const TextStyle(
                      color: AuthColors.textMain,
                      fontSize: 13,
                      fontFamily: 'SF Pro Display',
                    ),
                    textAlign: TextAlign.center,
                  );
                }

                // Apply alignment - default to center if not explicitly set
                final alignment = column.alignment == Alignment.centerLeft 
                    ? Alignment.center 
                    : column.alignment;
                cell = Align(
                  alignment: alignment,
                  child: cell,
                );

                if (width != null) {
                  return SizedBox(
                    width: width,
                    child: cell,
                  );
                } else {
                  return Expanded(
                    flex: flex,
                    child: cell,
                  );
                }
              }),
              if (widget.rowActions != null && widget.rowActions!.isNotEmpty) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: (widget.rowActions!.length * 52).toDouble(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: widget.rowActions!.map((action) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: IconButton(
                          icon: Icon(
                            action.icon,
                            size: 24,
                            color: action.color ?? AuthColors.textSub,
                          ),
                          onPressed: () => action.onTap(widget.row, widget.rowIndex),
                          tooltip: action.tooltip,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            padding: const EdgeInsets.all(10),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.icon,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AuthColors.textMainWithOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: AuthColors.textDisabled,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AuthColors.textSub,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
