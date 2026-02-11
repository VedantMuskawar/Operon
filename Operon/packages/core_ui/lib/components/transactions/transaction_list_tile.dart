import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_models/core_models.dart';

/// Unified transaction list tile component
/// Displays transaction information consistently across platforms
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.transaction,
    required this.title,
    this.subtitle,
    this.formatCurrency,
    this.formatDate,
    this.onTap,
    this.onDelete,
    this.isGridView = false,
  });

  final Transaction transaction;
  final String title;
  final String? subtitle;
  final String Function(double)? formatCurrency;
  final String Function(DateTime)? formatDate;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool isGridView;

  String _formatCurrency(double amount) {
    if (formatCurrency != null) {
      return formatCurrency!(amount);
    }
    return '₹${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  String _formatDate(DateTime date) {
    if (formatDate != null) {
      return formatDate!(date);
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  Color _getAmountColor() {
    switch (transaction.type) {
      case TransactionType.credit:
        return AuthColors.success;
      case TransactionType.debit:
        return AuthColors.error;
    }
  }

  Color _getNeutralBorderColor() => AuthColors.textMainWithOpacity(0.10);

  Color _getNeutralIconColor() => AuthColors.textSub;

  IconData _getIcon() {
    switch (transaction.category) {
      case TransactionCategory.clientPayment:
        return Icons.payment;
      case TransactionCategory.vendorPurchase:
        return Icons.shopping_cart;
      case TransactionCategory.vendorPayment:
        return Icons.store;
      case TransactionCategory.salaryDebit:
        return Icons.person;
      case TransactionCategory.generalExpense:
        return Icons.receipt;
      default:
        return Icons.receipt_long;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountColor = _getAmountColor();
    final amount = transaction.amount;
    final date = transaction.createdAt ?? DateTime.now();
    final balanceAfter = transaction.balanceAfter;

    if (isGridView) {
      return _buildGridTile(context, amountColor, amount, date, balanceAfter);
    }
    return _buildListTile(context, amountColor, amount, date, balanceAfter);
  }

  Widget _buildGridTile(
    BuildContext context,
    Color amountColor,
    double amount,
    DateTime date,
    double? balanceAfter,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AuthColors.surface, AuthColors.background],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _getNeutralBorderColor(),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AuthColors.surface.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _getNeutralBorderColor()),
                  ),
                  child: Icon(_getIcon(), color: _getNeutralIconColor(), size: 18),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Text(
              _formatDate(date),
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(amount),
                      style: TextStyle(
                        color: amountColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (balanceAfter != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Bal: ${_formatCurrency(balanceAfter)}',
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ],
                ),
                if (onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: AuthColors.error,
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context,
    Color amountColor,
    double amount,
    DateTime date,
    double? balanceAfter,
  ) {
    // Build subtitle text - show reference number if available, otherwise use subtitle prop
    final hasReference = transaction.referenceNumber != null &&
        transaction.referenceNumber!.trim().isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    
    String? subtitleText;
    if (hasReference) {
      subtitleText = 'Ref: ${transaction.referenceNumber!.trim()}';
      // If there's also a custom subtitle, append it
      if (hasSubtitle && subtitle!.trim() != subtitleText) {
        subtitleText = '$subtitleText • ${subtitle!.trim()}';
      }
    } else if (hasSubtitle) {
      subtitleText = subtitle!.trim();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AuthColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _getNeutralBorderColor()),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Row 1: Name (left) + Amount (right)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AuthColors.textMain,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatCurrency(amount),
                          style: TextStyle(
                            color: amountColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Row 2: Subtitle (if available)
                    if (subtitleText != null && subtitleText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Row 3: Balance + Delete button
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (balanceAfter != null) ...[
                          Expanded(
                            child: Text(
                              'Balance: ${_formatCurrency(balanceAfter)}',
                              style: const TextStyle(
                                color: AuthColors.textSub,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else ...[
                          const Spacer(),
                        ],
                        if (onDelete != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: AuthColors.error,
                            onPressed: onDelete,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
