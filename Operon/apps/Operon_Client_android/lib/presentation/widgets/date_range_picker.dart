import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

class DateRangePicker extends StatelessWidget {
  const DateRangePicker({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final DateTime? startDate;
  final DateTime? endDate;
  final ValueChanged<DateTime?> onStartDateChanged;
  final ValueChanged<DateTime?> onEndDateChanged;

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Future<void> _selectDate(
    BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    ValueChanged<DateTime?> onDateSelected,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AuthColors.legacyAccent,
              onPrimary: AuthColors.textMain,
              surface: AuthColors.surface,
              onSurface: AuthColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      onDateSelected(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(
              context,
              startDate,
              null,
              endDate ?? DateTime.now(),
              onStartDateChanged,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: startDate != null
                      ? AuthColors.legacyAccent.withOpacity(0.5)
                      : AuthColors.textMainWithOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      startDate != null ? _formatDate(startDate!) : 'Start Date',
                      style: TextStyle(
                        color: startDate != null ? AuthColors.textMain : AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _selectDate(
              context,
              endDate,
              startDate ?? DateTime(2000),
              DateTime.now(),
              onEndDateChanged,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: endDate != null
                      ? AuthColors.legacyAccent.withOpacity(0.5)
                      : AuthColors.textMainWithOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AuthColors.textSub, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      endDate != null ? _formatDate(endDate!) : 'End Date',
                      style: TextStyle(
                        color: endDate != null ? AuthColors.textMain : AuthColors.textSub,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

