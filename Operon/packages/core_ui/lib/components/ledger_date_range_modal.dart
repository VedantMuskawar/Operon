import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;

/// Shows a date range picker modal for ledger PDF generation
/// Returns the selected date range or null if cancelled
Future<DateTimeRange?> showLedgerDateRangeModal(BuildContext context) async {
  final now = DateTime.now();
  final firstDate = DateTime(now.year - 5, 1, 1);
  final lastDate = DateTime(now.year + 1, 12, 31);

  // Default to current month
  final initialStartDate = DateTime(now.year, now.month, 1);
  final initialEndDate = DateTime(now.year, now.month + 1, 0);

  DateTimeRange? selectedRange = DateTimeRange(
    start: initialStartDate,
    end: initialEndDate,
  );

  return showDialog<DateTimeRange>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (dialogContext) => _LedgerDateRangeModalDialog(
      initialRange: selectedRange,
      firstDate: firstDate,
      lastDate: lastDate,
      onCancel: () => Navigator.of(dialogContext).pop(),
      onConfirm: (range) => Navigator.of(dialogContext).pop(range),
    ),
  );
}

class _LedgerDateRangeModalDialog extends StatefulWidget {
  const _LedgerDateRangeModalDialog({
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    required this.onCancel,
    required this.onConfirm,
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;
  final VoidCallback onCancel;
  final ValueChanged<DateTimeRange> onConfirm;

  @override
  State<_LedgerDateRangeModalDialog> createState() => _LedgerDateRangeModalDialogState();
}

class _LedgerDateRangeModalDialogState extends State<_LedgerDateRangeModalDialog> {
  late DateTimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.initialRange;
  }

  DateTimeRange get selectedRange => _selectedRange;

  Future<void> _selectStartDate() async {
    final maxDate = _selectedRange.end.isAfter(_selectedRange.start)
        ? _selectedRange.end.subtract(const Duration(days: 1))
        : widget.lastDate;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedRange.start,
      firstDate: widget.firstDate,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: picked,
          end: _selectedRange.end,
        );
      });
    }
  }

  Future<void> _selectEndDate() async {
    final minDate = _selectedRange.start.isBefore(_selectedRange.end)
        ? _selectedRange.start.add(const Duration(days: 1))
        : widget.firstDate;
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedRange.end,
      firstDate: minDate,
      lastDate: widget.lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.primary,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedRange = DateTimeRange(
          start: _selectedRange.start,
          end: picked,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AuthColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: AuthColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Select Date Range',
                      style: TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AuthColors.textSub,
                      size: 20,
                    ),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Date Picker
                  InkWell(
                    onTap: _selectStartDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AuthColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AuthColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'From Date',
                                  style: TextStyle(
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(selectedRange.start),
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AuthColors.textSub,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // End Date Picker
                  InkWell(
                    onTap: _selectEndDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AuthColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AuthColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'To Date',
                                  style: TextStyle(
                                    color: AuthColors.textSub,
                                    fontSize: 12,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatDate(selectedRange.end),
                                  style: const TextStyle(
                                    color: AuthColors.textMain,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: AuthColors.textSub,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AuthColors.textSub,
                            fontFamily: 'SF Pro Display',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => widget.onConfirm(_selectedRange),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuthColors.primary,
                          foregroundColor: AuthColors.textMain,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontFamily: 'SF Pro Display',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
