import 'package:flutter/material.dart';
import 'package:core_models/core_models.dart';
import '../theme/auth_colors.dart';

/// Document-style view for a salary payment (cash voucher).
/// Shows org context, date, employee, amount, payment account, reference, and proof photo.
/// Use for transactions with category [TransactionCategory.salaryDebit].
class CashVoucherView extends StatelessWidget {
  const CashVoucherView({
    super.key,
    required this.transaction,
    this.organizationName,
    this.employeeName,
  });

  final Transaction transaction;
  /// Optional organization display name (e.g. from org context).
  final String? organizationName;
  /// Optional employee display name; falls back to [Transaction.metadata] ['employeeName'].
  final String? employeeName;

  String get _employeeName =>
      employeeName?.trim().isNotEmpty == true
          ? employeeName!
          : (transaction.metadata?['employeeName']?.toString().trim() ?? '—');

  String? get _voucherPhotoUrl =>
      transaction.metadata?['cashVoucherPhotoUrl']?.toString();

  static const List<String> _ones = [
    '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
    'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
    'Seventeen', 'Eighteen', 'Nineteen',
  ];
  static const List<String> _tens = [
    '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety',
  ];

  static String _amountInWords(double amount) {
    if (amount <= 0) return 'Zero only';
    final intPart = amount.floor();
    final decPart = ((amount - intPart) * 100).round();
    if (intPart == 0) {
      return '${decPart > 0 ? "$decPart/100 " : ""}only';
    }
    String words = _intToWords(intPart);
    if (decPart > 0) {
      words += ' and $decPart/100';
    }
    return '$words only';
  }

  static String _intToWords(int n) {
    if (n == 0) return '';
    if (n < 20) return _ones[n];
    if (n < 100) return '${_tens[n ~/ 10]} ${_ones[n % 10]}'.trim();
    if (n < 1000) return '${_ones[n ~/ 100]} Hundred ${_intToWords(n % 100)}'.trim();
    if (n < 100000) return '${_intToWords(n ~/ 1000)} Thousand ${_intToWords(n % 1000)}'.trim();
    if (n < 10000000) return '${_intToWords(n ~/ 100000)} Lakh ${_intToWords(n % 100000)}'.trim();
    return '${_intToWords(n ~/ 10000000)} Crore ${_intToWords(n % 10000000)}'.trim();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = date.day.toString().padLeft(2, '0');
    final m = months[date.month - 1];
    final y = date.year;
    return '$d $m $y';
  }

  String _formatCurrency(double amount) {
    return '₹${amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _voucherPhotoUrl;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final date = transaction.createdAt ?? DateTime.now();

    return Container(
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuthColors.textMainWithOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              organizationName ?? 'Organization',
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cash Voucher',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Salary Payment',
              style: TextStyle(
                color: AuthColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(height: 1, color: AuthColors.textSub),
            const SizedBox(height: 20),
            // Body rows
            _row('Date', _formatDate(date)),
            _row('Employee', _employeeName),
            _row('Amount', _formatCurrency(transaction.amount)),
            _row('Amount (in words)', _amountInWords(transaction.amount)),
            if (transaction.paymentAccountName != null && transaction.paymentAccountName!.isNotEmpty)
              _row('Payment Account', transaction.paymentAccountName!),
            if (transaction.referenceNumber != null && transaction.referenceNumber!.isNotEmpty)
              _row('Reference', transaction.referenceNumber!),
            if (transaction.description != null && transaction.description!.isNotEmpty)
              _row('Description', transaction.description!),
            const SizedBox(height: 24),
            // Proof photo
            if (hasPhoto) ...[
              const Text(
                'Proof of Payment',
                style: TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                          color: AuthColors.primary,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    alignment: Alignment.center,
                    color: AuthColors.surface,
                    child: const Text(
                      'Failed to load image',
                      style: TextStyle(color: AuthColors.textSub, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuthColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AuthColors.textMainWithOpacity(0.1)),
                ),
                child: const Text(
                  'No voucher photo',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AuthColors.textSub,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
