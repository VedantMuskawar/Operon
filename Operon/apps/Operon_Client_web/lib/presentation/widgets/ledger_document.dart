import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:core_utils/core_utils.dart' show LedgerRowData, PdfBuilder;
import 'package:flutter/material.dart';

/// Flutter widget that displays ledger statement content (same data as PDF).
/// Use inside RepaintBoundary + GlobalKey for PNG capture. AuthColors styling.
List<String> _headersForLedgerType(LedgerType ledgerType) {
  switch (ledgerType) {
    case LedgerType.clientLedger:
      return ['Date', 'DM No.', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    case LedgerType.employeeLedger:
      return ['Date', 'Batch/Trip', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    case LedgerType.vendorLedger:
      return ['Date', 'Invoice No.', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
    default:
      return ['Date', 'Reference', 'Debit', 'Credit', 'Balance', 'Type', 'Remarks'];
  }
}

class LedgerDocument extends StatelessWidget {
  const LedgerDocument({
    super.key,
    required this.ledgerType,
    required this.entityName,
    required this.transactions,
    required this.openingBalance,
    required this.companyHeader,
    required this.startDate,
    required this.endDate,
    this.logoBytes,
  });

  final LedgerType ledgerType;
  final String entityName;
  final List<LedgerRowData> transactions;
  final double openingBalance;
  final DmHeaderSettings companyHeader;
  final DateTime startDate;
  final DateTime endDate;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    final headers = _headersForLedgerType(ledgerType);
    final totalDebit =
        transactions.fold<double>(0, (sum, row) => sum + row.debit);
    final totalCredit =
        transactions.fold<double>(0, (sum, row) => sum + row.credit);
    final closingBalance = openingBalance + totalCredit - totalDebit;

    final openingRow = LedgerRowData(
      date: startDate,
      reference: 'Opening Balance',
      debit: openingBalance < 0 ? -openingBalance : 0.0,
      credit: openingBalance >= 0 ? openingBalance : 0.0,
      balance: openingBalance,
      type: 'Opening Balance',
      remarks: '-',
    );
    final allRows = [openingRow, ...transactions];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 35),
      color: AuthColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildTitle(),
          const SizedBox(height: 18),
          _buildTable(headers, allRows),
          const SizedBox(height: 16),
          _buildSummary(
            openingBalance: openingBalance,
            totalDebit: totalDebit,
            totalCredit: totalCredit,
            closingBalance: closingBalance,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AuthColors.info, width: 2),
        ),
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (logoBytes != null && logoBytes!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                logoBytes!,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  companyHeader.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AuthColors.textMain,
                  ),
                ),
                if (companyHeader.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    companyHeader.address,
                    style: const TextStyle(fontSize: 10, color: AuthColors.textSub),
                  ),
                ],
                if (companyHeader.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    companyHeader.phone,
                    style: const TextStyle(fontSize: 10, color: AuthColors.textSub),
                  ),
                ],
                if (companyHeader.gstNo != null &&
                    companyHeader.gstNo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GST: ${companyHeader.gstNo}',
                    style: const TextStyle(fontSize: 10, color: AuthColors.textSub),
                  ),
                ],
              ],
            ),
          ),
          const Text(
            'LEDGER STATEMENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AuthColors.textSub,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.textSub.withOpacity(0.15),
        border: const Border(
          left: BorderSide(color: AuthColors.textSub, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entityName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AuthColors.textMain,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${PdfBuilder.formatDateDDMMYYYY(startDate)} to ${PdfBuilder.formatDateDDMMYYYY(endDate)}',
            style: const TextStyle(fontSize: 9, color: AuthColors.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<String> headers, List<LedgerRowData> allRows) {
    return Table(
      columnWidths: {
        for (int i = 0; i < 7; i++) i: const FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AuthColors.textSub.withOpacity(0.2),
          ),
          children: headers.map((h) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Text(
                h.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.textMain,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
        ...List.generate(allRows.length, (index) {
          final row = allRows[index];
          final isOpening = index == 0;
          final isEven = index % 2 == 0;
          final bg = isOpening
              ? AuthColors.textSub.withOpacity(0.2)
              : (isEven
                  ? AuthColors.surface
                  : AuthColors.textSub.withOpacity(0.08));
          return TableRow(
            decoration: BoxDecoration(color: bg),
            children: [
              _cell(PdfBuilder.formatDateDDMMYYYY(row.date), TextAlign.center, bg),
              _cell(row.reference, TextAlign.center, bg),
              _cell(
                row.debit > 0 ? PdfBuilder.formatCurrency(row.debit) : '-',
                TextAlign.right,
                bg,
                isNumeric: true,
              ),
              _cell(
                row.credit > 0 ? PdfBuilder.formatCurrency(row.credit) : '-',
                TextAlign.right,
                bg,
                isNumeric: true,
              ),
              _cell(
                PdfBuilder.formatCurrency(row.balance),
                TextAlign.right,
                bg,
                isBold: true,
                valueColor: row.balance >= 0
                    ? AuthColors.success
                    : AuthColors.error,
                isNumeric: true,
              ),
              _cell(row.type, TextAlign.center, bg),
              _cell(row.remarks, TextAlign.left, bg),
            ],
          );
        }),
      ],
    );
  }

  Widget _cell(
    String text,
    TextAlign align,
    Color bg, {
    bool isBold = false,
    Color? valueColor,
    bool isNumeric = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: bg,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: valueColor ?? AuthColors.textMain,
        ),
        textAlign: align,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildSummary({
    required double openingBalance,
    required double totalDebit,
    required double totalCredit,
    required double closingBalance,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.4),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Opening Balance',
                style: TextStyle(
                  fontSize: 9,
                  color: AuthColors.textSub,
                ),
              ),
              Text(
                PdfBuilder.formatCurrency(openingBalance),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Debit',
                      style: TextStyle(
                        fontSize: 9,
                        color: AuthColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PdfBuilder.formatCurrency(totalDebit),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AuthColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Credit',
                      style: TextStyle(
                        fontSize: 9,
                        color: AuthColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PdfBuilder.formatCurrency(totalCredit),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AuthColors.textMain,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AuthColors.textSub.withOpacity(0.1),
                    border: Border.all(
                      color: AuthColors.textSub.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Net Balance',
                        style: TextStyle(
                          fontSize: 9,
                          color: AuthColors.textSub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        PdfBuilder.formatCurrency(closingBalance),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: closingBalance >= 0
                              ? AuthColors.success
                              : AuthColors.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
