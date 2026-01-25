import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';

/// Sticky header for date grouping in transaction lists
/// Shows formatted date strings like "Today", "Yesterday", "This Week"
class TransactionDateGroupHeader extends StatelessWidget {
  const TransactionDateGroupHeader({
    super.key,
    required this.date,
  });

  final DateTime date;

  String _getGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(weekAgo)) {
      return 'This Week';
    } else {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      
      // Show year only if different from current year
      if (year != now.year) {
        return '$day $month $year';
      }
      return '$day $month';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textMainWithOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AuthColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _getGroupLabel(date),
            style: const TextStyle(
              color: AuthColors.textMain,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
