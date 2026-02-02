import 'package:core_ui/core_ui.dart';
import 'package:dash_web/presentation/blocs/weekly_ledger/weekly_ledger_cubit.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Dialog to select a week for Weekly Ledger generation.
/// Defaults to current week, allows navigation to previous/next weeks,
/// and allows selecting a date to jump to that week.
class WeeklyLedgerWeekDialog extends StatefulWidget {
  const WeeklyLedgerWeekDialog({super.key});

  @override
  State<WeeklyLedgerWeekDialog> createState() => _WeeklyLedgerWeekDialogState();
}

class _WeeklyLedgerWeekDialogState extends State<WeeklyLedgerWeekDialog> {
  late DateTime _selectedDate;
  late DateTime _weekStart;
  late DateTime _weekEnd;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _weekStart = WeeklyLedgerCubit.weekStart(now);
    _weekEnd = WeeklyLedgerCubit.weekEnd(now);
  }

  void _updateWeek(DateTime date) {
    setState(() {
      _selectedDate = date;
      _weekStart = WeeklyLedgerCubit.weekStart(date);
      _weekEnd = WeeklyLedgerCubit.weekEnd(date);
    });
  }

  void _previousWeek() {
    _updateWeek(_weekStart.subtract(const Duration(days: 1)));
  }

  void _nextWeek() {
    _updateWeek(_weekEnd.add(const Duration(days: 1)));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: DashTheme.light(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateWeek(picked);
    }
  }

  String _formatWeekRange() {
    final startFormat = DateFormat('MMM d');
    final endFormat = DateFormat('MMM d, yyyy');
    return '${startFormat.format(_weekStart)} - ${endFormat.format(_weekEnd)}';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthColors.surface, AuthColors.background],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AuthColors.background.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Week',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const SizedBox(height: 24),
            // Week range display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AuthColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AuthColors.textMainWithOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AuthColors.textMain),
                    onPressed: _previousWeek,
                    tooltip: 'Previous week',
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _selectDate,
                      child: Column(
                        children: [
                          Text(
                            _formatWeekRange(),
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'SF Pro Display',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to select date',
                            style: TextStyle(
                              color: AuthColors.textSub,
                              fontSize: 12,
                              fontFamily: 'SF Pro Display',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AuthColors.textMain),
                    onPressed: _nextWeek,
                    tooltip: 'Next week',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DashButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                  variant: DashButtonVariant.outlined,
                ),
                const SizedBox(width: 12),
                DashButton(
                  label: 'Generate',
                  onPressed: () {
                    Navigator.of(context).pop({
                      'weekStart': _weekStart,
                      'weekEnd': _weekEnd,
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
