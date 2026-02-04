import 'dart:typed_data';

import 'package:core_models/core_models.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:core_utils/core_utils.dart' show FuelLedgerRow, PdfBuilder;
import 'package:flutter/material.dart';

/// Flutter widget for Fuel Ledger (same data as PDF). Use inside RepaintBoundary for PNG capture.
class FuelLedgerDocument extends StatelessWidget {
  const FuelLedgerDocument({
    super.key,
    required this.companyHeader,
    required this.vendorName,
    required this.rows,
    required this.total,
    this.paymentMode,
    this.paymentDate,
    this.logoBytes,
  });

  final DmHeaderSettings companyHeader;
  final String vendorName;
  final List<FuelLedgerRow> rows;
  final double total;
  final String? paymentMode;
  final DateTime? paymentDate;
  final Uint8List? logoBytes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 35),
      color: AuthColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildVendorTitle(),
          const SizedBox(height: 14),
          _buildTable(),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
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
                    style: TextStyle(fontSize: 10, color: AuthColors.textSub),
                  ),
                ],
                if (companyHeader.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    companyHeader.phone,
                    style: TextStyle(fontSize: 10, color: AuthColors.textSub),
                  ),
                ],
              ],
            ),
          ),
          const Text(
            'FUEL LEDGER',
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

  Widget _buildVendorTitle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AuthColors.textSub.withOpacity(0.15),
        border: Border(
          left: BorderSide(color: AuthColors.textSub, width: 3),
        ),
      ),
      child: Text(
        vendorName,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AuthColors.textMain,
        ),
      ),
    );
  }

  Widget _buildTable() {
    const headers = ['VOUCHER', 'DATE', 'AMOUNT', 'VEHICLE NO'];
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.2),
      },
      border: TableBorder.all(
        color: AuthColors.textSub.withOpacity(0.4),
        width: 0.5,
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: AuthColors.textSub.withOpacity(0.2),
          ),
          children: headers
              .map(
                (h) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(
                    h,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AuthColors.textMain,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final bg = index % 2 == 0
              ? AuthColors.surface
              : AuthColors.textSub.withOpacity(0.08);
          return TableRow(
            decoration: BoxDecoration(color: bg),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  row.voucher,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  PdfBuilder.formatDateDDMMYYYY(row.date),
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  PdfBuilder.formatCurrency(row.amount),
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AuthColors.textMain,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  row.vehicleNo,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildFooter() {
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
                'Total',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.textMain,
                ),
              ),
              Text(
                PdfBuilder.formatCurrency(total),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.textMain,
                ),
              ),
            ],
          ),
          if (paymentMode != null && paymentMode!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Mode',
                  style: TextStyle(fontSize: 9, color: AuthColors.textSub),
                ),
                Text(
                  paymentMode!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AuthColors.textMain,
                  ),
                ),
              ],
            ),
          ],
          if (paymentDate != null) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Date',
                  style: TextStyle(fontSize: 9, color: AuthColors.textSub),
                ),
                Text(
                  PdfBuilder.formatDateDDMMYYYY(paymentDate!),
                  style: const TextStyle(
                    fontSize: 9,
                    color: AuthColors.textMain,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
