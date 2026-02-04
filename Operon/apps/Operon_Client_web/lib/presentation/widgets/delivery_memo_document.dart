import 'dart:typed_data';
import 'package:core_models/core_models.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:core_utils/core_utils.dart' show PdfBuilder;
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:flutter/material.dart';

/// Native Flutter widget that displays Delivery Memo content (Web).
/// Uses the same data source as the PDF generator for visual parity.
/// Must be wrapped in a [RepaintBoundary] with a unique [GlobalKey] for PNG capture.
/// Layout approximates A4 (caller should wrap in AspectRatio or ConstrainedBox).
class DeliveryMemoDocument extends StatelessWidget {
  const DeliveryMemoDocument({
    super.key,
    required this.dmData,
    required this.payload,
  });

  final Map<String, dynamic> dmData;
  final DmViewPayload payload;

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is Map && date.containsKey('_seconds')) {
      return DateTime.fromMillisecondsSinceEpoch(
        (date['_seconds'] as int) * 1000,
      );
    }
    if (date.toString().contains('-')) {
      try {
        return DateTime.parse(date.toString());
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final dmNumber = dmData['dmNumber'] as int? ??
        (dmData['dmNumber'] as num?)?.toInt() ??
        0;
    final scheduledDate = _parseDate(dmData['scheduledDate']);
    final clientName = dmData['clientName'] as String? ?? 'N/A';
    final clientPhone = dmData['clientPhone'] as String? ??
        dmData['customerNumber'] as String? ??
        '';
    final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';
    final driverName = (dmData['driverName'] as String?) ?? 'N/A';
    final driverPhone = dmData['driverPhone'] as String?;
    final deliveryZone = dmData['deliveryZone'] as Map<String, dynamic>?;
    final itemsData = dmData['items'];
    final items = itemsData is List
        ? itemsData
        : (itemsData != null ? [itemsData] : []);
    final tripPricing = dmData['tripPricing'] is Map<String, dynamic>
        ? dmData['tripPricing'] as Map<String, dynamic>
        : <String, dynamic>{};
    final subtotal =
        (tripPricing['subtotal'] as num?)?.toDouble() ?? 0.0;
    final total = (tripPricing['total'] as num?)?.toDouble() ?? 0.0;
    final advanceDeducted =
        (tripPricing['advanceAmountDeducted'] as num?)?.toDouble();
    final header = payload.dmSettings.header;
    final isPortrait =
        payload.dmSettings.printOrientation == DmPrintOrientation.portrait;
    final showQrCode =
        payload.dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AuthColors.surface,
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(header),
          const SizedBox(height: 10),
          _buildDmInfo(
            dmNumber: dmNumber,
            date: scheduledDate,
            clientName: clientName,
            clientPhone: clientPhone,
            vehicleNumber: vehicleNumber,
            driverName: driverName,
            driverPhone: driverPhone,
            deliveryZone: deliveryZone,
            isPortrait: isPortrait,
          ),
          const SizedBox(height: 12),
          if (isPortrait) ...[
            _buildItemsTable(items),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildPricingSummary(
                    subtotal: subtotal,
                    advanceDeducted: advanceDeducted,
                    total: total,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildPaymentSection(
                    paymentAccount: payload.paymentAccount,
                    showQrCode: showQrCode,
                    qrCodeBytes: payload.qrCodeBytes,
                    isPortrait: true,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildItemsTable(items),
                      const SizedBox(height: 10),
                      _buildPricingSummary(
                        subtotal: subtotal,
                        advanceDeducted: advanceDeducted,
                        total: total,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildPaymentSection(
                    paymentAccount: payload.paymentAccount,
                    showQrCode: showQrCode,
                    qrCodeBytes: payload.qrCodeBytes,
                    isPortrait: false,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildFooter(payload.dmSettings.footer),
        ],
      ),
    );
  }

  Widget _buildHeader(DmHeaderSettings header) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AuthColors.textSub.withOpacity(0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (payload.logoBytes != null && payload.logoBytes!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                payload.logoBytes!,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AuthColors.textMain,
                  ),
                ),
                if (header.address.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    header.address,
                    style: TextStyle(
                      fontSize: 10,
                      color: AuthColors.textSub,
                    ),
                  ),
                ],
                if (header.phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    header.phone,
                    style: TextStyle(
                      fontSize: 10,
                      color: AuthColors.textSub,
                    ),
                  ),
                ],
                if (header.gstNo != null && header.gstNo!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GST: ${header.gstNo}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AuthColors.textSub,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDmInfo({
    required int dmNumber,
    required DateTime date,
    required String clientName,
    required String clientPhone,
    required String vehicleNumber,
    required String driverName,
    String? driverPhone,
    Map<String, dynamic>? deliveryZone,
    required bool isPortrait,
  }) {
    final zoneText = deliveryZone != null
        ? '${deliveryZone['region'] ?? ''}, ${deliveryZone['city_name'] ?? deliveryZone['city'] ?? ''}'
        : '';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AuthColors.textSub.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DM No: DM-$dmNumber',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AuthColors.info,
                ),
              ),
              Text(
                'Date: ${PdfBuilder.formatDate(date)}',
                style: TextStyle(
                  fontSize: 10,
                  color: AuthColors.textSub,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Client: $clientName${clientPhone.isNotEmpty ? ' ($clientPhone)' : ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              if (zoneText.isNotEmpty)
                Text(
                  'Zone: $zoneText',
                  style: TextStyle(
                    fontSize: 10,
                    color: AuthColors.textSub,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Vehicle: $vehicleNumber',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AuthColors.textMain,
                  ),
                ),
              ),
              if (driverName != 'N/A' && driverName.isNotEmpty)
                Expanded(
                  child: Text(
                    'Driver: $driverName${driverPhone != null && driverPhone.isNotEmpty ? ' ($driverPhone)' : ''}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AuthColors.textMain,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List<dynamic> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AuthColors.textSub.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            'No items',
            style: TextStyle(
              fontSize: 11,
              color: AuthColors.textSub,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(
            color: AuthColors.textSub.withOpacity(0.3),
            width: 0.5,
          ),
          verticalInside: BorderSide(
            color: AuthColors.textSub.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(0.8),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(color: AuthColors.info),
            children: [
              _tableCell('Product', bold: true, color: AuthColors.textMain),
              _tableCell('Qty', bold: true, color: AuthColors.textMain),
              _tableCell('Unit Price', bold: true, color: AuthColors.textMain),
              _tableCell('Total', bold: true, color: AuthColors.textMain),
            ],
          ),
          ...List.generate(items.length, (i) {
            final item = items[i];
            final itemMap =
                item is Map<String, dynamic> ? item : <String, dynamic>{};
            final productName = itemMap['productName'] as String? ??
                itemMap['name'] as String? ??
                'N/A';
            final quantity =
                (itemMap['fixedQuantityPerTrip'] as num?)?.toInt() ??
                    (itemMap['totalQuantity'] as num?)?.toInt() ??
                    (itemMap['quantity'] as num?)?.toInt() ??
                    0;
            final unitPrice =
                (itemMap['unitPrice'] as num?)?.toDouble() ??
                    (itemMap['price'] as num?)?.toDouble() ??
                    0.0;
            final lineTotal =
                (itemMap['total'] as num?)?.toDouble() ??
                    (itemMap['lineTotal'] as num?)?.toDouble() ??
                    (itemMap['amount'] as num?)?.toDouble() ??
                    (quantity * unitPrice);
            final isEven = i % 2 == 0;
            return TableRow(
              decoration: BoxDecoration(
                color: isEven
                    ? AuthColors.surface
                    : AuthColors.textSub.withOpacity(0.08),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AuthColors.textMain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    quantity.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AuthColors.textMain,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    PdfBuilder.formatCurrency(unitPrice),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AuthColors.textMain,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    PdfBuilder.formatCurrency(lineTotal),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AuthColors.info,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableCell(String text,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AuthColors.textMain,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPricingSummary({
    required double subtotal,
    double? advanceDeducted,
    required double total,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
        color: AuthColors.textSub.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (subtotal != total) ...[
            _labelValue('Subtotal:', PdfBuilder.formatCurrency(subtotal)),
            const SizedBox(height: 5),
          ],
          if (advanceDeducted != null && advanceDeducted > 0) ...[
            _labelValue(
              'Advance Deducted:',
              PdfBuilder.formatCurrency(advanceDeducted),
              valueColor: AuthColors.error,
            ),
            const SizedBox(height: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AuthColors.info.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: _labelValue(
              'Total:',
              PdfBuilder.formatCurrency(total),
              labelSize: 12,
              valueSize: 12,
              valueBold: true,
              valueColor: AuthColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _labelValue(
    String label,
    String value, {
    double labelSize = 10,
    double valueSize = 10,
    bool valueBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: labelSize,
            color: AuthColors.textSub,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: valueBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? AuthColors.textMain,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection({
    Map<String, dynamic>? paymentAccount,
    required bool showQrCode,
    Uint8List? qrCodeBytes,
    required bool isPortrait,
  }) {
    if (paymentAccount == null) return const SizedBox.shrink();

    final accountName = paymentAccount['name'] as String? ?? '';
    final upiId = paymentAccount['upiId'] as String?;

    if (showQrCode &&
        qrCodeBytes != null &&
        qrCodeBytes.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: AuthColors.info,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: AuthColors.textSub.withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Payment QR Code',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AuthColors.info,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AuthColors.textSub.withOpacity(0.4),
                ),
              ),
              child: Image.memory(
                qrCodeBytes,
                width: isPortrait ? 120 : 100,
                height: isPortrait ? 120 : 100,
                fit: BoxFit.contain,
              ),
            ),
            if (accountName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                accountName,
                style: TextStyle(
                  fontSize: 10,
                  color: AuthColors.textSub,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (upiId != null && upiId.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                upiId,
                style: TextStyle(
                  fontSize: 8,
                  color: AuthColors.textSub,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    if (showQrCode &&
        upiId != null &&
        upiId.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: AuthColors.warning,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(6),
          color: AuthColors.textSub.withOpacity(0.08),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'UPI Payment',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AuthColors.info,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AuthColors.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AuthColors.textSub.withOpacity(0.4),
                ),
              ),
              child: Text(
                upiId,
                style: const TextStyle(
                  fontSize: 11,
                  color: AuthColors.textMain,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (accountName.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                accountName,
                style: TextStyle(
                  fontSize: 9,
                  color: AuthColors.textSub,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    final accountNumber = paymentAccount['accountNumber'] as String?;
    final ifscCode = paymentAccount['ifscCode'] as String?;
    if (accountNumber == null && ifscCode == null && upiId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(
          color: AuthColors.textSub.withOpacity(0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
        color: AuthColors.textSub.withOpacity(0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AuthColors.info,
            ),
          ),
          const SizedBox(height: 8),
          if (accountName.isNotEmpty) ...[
            _labelValue('Account Name:', accountName, labelSize: 11, valueSize: 11),
            const SizedBox(height: 6),
          ],
          if (accountNumber != null && accountNumber.isNotEmpty) ...[
            _labelValue('Account Number:', accountNumber, labelSize: 11, valueSize: 11),
            const SizedBox(height: 6),
          ],
          if (ifscCode != null && ifscCode.isNotEmpty) ...[
            _labelValue('IFSC Code:', ifscCode, labelSize: 11, valueSize: 11),
            const SizedBox(height: 6),
          ],
          if (upiId != null && upiId.isNotEmpty)
            _labelValue('UPI ID:', upiId, labelSize: 11, valueSize: 11),
        ],
      ),
    );
  }

  Widget _buildFooter(DmFooterSettings footer) {
    if (footer.customText == null || footer.customText!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        footer.customText!,
        style: TextStyle(
          fontSize: 9,
          color: AuthColors.textSub,
        ),
      ),
    );
  }
}
