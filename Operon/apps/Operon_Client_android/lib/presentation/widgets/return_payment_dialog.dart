import 'package:dash_mobile/domain/entities/payment_account.dart';
import 'package:flutter/material.dart';

class ReturnPaymentDialog extends StatefulWidget {
  const ReturnPaymentDialog({
    super.key,
    required this.paymentAccounts,
    required this.tripTotal,
    required this.alreadyPaid,
  });

  final List<PaymentAccount> paymentAccounts;
  final double tripTotal;
  final double alreadyPaid;

  @override
  State<ReturnPaymentDialog> createState() => _ReturnPaymentDialogState();
}

class _ReturnPaymentDialogState extends State<ReturnPaymentDialog> {
  final List<_PaymentEntry> _entries = [];

  double get _remainingBeforeEntries => (widget.tripTotal - widget.alreadyPaid).clamp(0, double.infinity);

  double get _enteredTotal =>
      _entries.fold<double>(0, (sum, e) => sum + (e.amount ?? 0));

  double get _remainingAfterEntries =>
      (_remainingBeforeEntries - _enteredTotal).clamp(0, double.infinity);

  bool get _isOverpay =>
      _enteredTotal > _remainingBeforeEntries + 0.0001; // small epsilon

  void _addEmptyEntry() {
    setState(() {
      _entries.add(const _PaymentEntry());
    });
  }

  void _removeEntry(int index) {
    setState(() {
      _entries.removeAt(index);
    });
  }

  void _updateEntryAccount(int index, PaymentAccount account) {
    setState(() {
      _entries[index] = _entries[index].copyWith(account: account);
    });
  }

  void _updateEntryAmount(int index, String amountStr) {
    final value = double.tryParse(amountStr);
    setState(() {
      _entries[index] = _entries[index].copyWith(amount: value);
    });
  }

  bool _validate() {
    if (_entries.isEmpty) return false;
    for (final entry in _entries) {
      if (entry.account == null) return false;
      if (entry.amount == null || entry.amount! <= 0) return false;
    }
    if (_isOverpay) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Start with one empty row
    _addEmptyEntry();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: const Text(
        'Payments (Return)',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryRow('Trip Total', widget.tripTotal),
            _buildSummaryRow('Already Paid', widget.alreadyPaid),
            _buildSummaryRow('Remaining', _remainingBeforeEntries),
            const SizedBox(height: 12),
            if (_entries.isEmpty)
              const Text(
                'Add a payment entry',
                style: TextStyle(color: Colors.white70),
              ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(_entries.length, (index) {
                    final entry = _entries[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _PaymentEntryRow(
                        paymentAccounts: widget.paymentAccounts,
                        entry: entry,
                        onAccountChanged: (acct) =>
                            _updateEntryAccount(index, acct),
                        onAmountChanged: (amt) =>
                            _updateEntryAmount(index, amt),
                        onRemove: _entries.length > 1
                            ? () => _removeEntry(index)
                            : null,
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isOverpay)
              const Text(
                'Amount exceeds remaining',
                style: TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Entered: ₹${_enteredTotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  'After: ₹${_remainingAfterEntries.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: _remainingAfterEntries == 0
                        ? Colors.greenAccent
                        : Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addEmptyEntry,
                icon: const Icon(Icons.add, color: Colors.white70),
                label: const Text(
                  'Add Payment',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _validate()
              ? () {
                  Navigator.of(context).pop(
                    _entries
                        .map((e) => {
                              'paymentAccountId': e.account!.id,
                              'paymentAccountName': e.account!.name,
                              'paymentAccountType': e.account!.type.name,
                              'amount': e.amount!,
                            })
                        .toList(),
                  );
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: const Text('Save Payments'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('₹${value.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _PaymentEntry {
  const _PaymentEntry({this.account, this.amount});

  final PaymentAccount? account;
  final double? amount;

  _PaymentEntry copyWith({PaymentAccount? account, double? amount}) {
    return _PaymentEntry(
      account: account ?? this.account,
      amount: amount ?? this.amount,
    );
  }
}

class _PaymentEntryRow extends StatelessWidget {
  const _PaymentEntryRow({
    required this.paymentAccounts,
    required this.entry,
    required this.onAccountChanged,
    required this.onAmountChanged,
    this.onRemove,
  });

  final List<PaymentAccount> paymentAccounts;
  final _PaymentEntry entry;
  final ValueChanged<PaymentAccount> onAccountChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<PaymentAccount>(
            initialValue: entry.account,
            dropdownColor: const Color(0xFF11111B),
            decoration: InputDecoration(
              labelText: 'Payment Account',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            iconEnabledColor: Colors.white70,
            style: const TextStyle(color: Colors.white),
            items: paymentAccounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account,
                    child: Text(account.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white)),
                  ),
                )
                .toList(),
            onChanged: (acct) {
              if (acct != null) onAccountChanged(acct);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: entry.amount?.toString() ?? '',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true, signed: false),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Amount',
              labelStyle: const TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onAmountChanged,
          ),
        ),
        if (onRemove != null) ...[
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ],
    );
  }
}


