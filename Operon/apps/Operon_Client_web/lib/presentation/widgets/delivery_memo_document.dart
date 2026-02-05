import 'dart:typed_data';
import 'package:core_models/core_models.dart';
import 'package:core_ui/theme/auth_colors.dart';
import 'package:core_utils/core_utils.dart' show PdfBuilder;
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Helper class for dashed line painter
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF888888)
      ..strokeWidth = 1;
    
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

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
    // Check if custom template is selected
    final isCustomTemplate = payload.dmSettings.templateType == DmTemplateType.custom &&
        payload.dmSettings.customTemplateId != null &&
        payload.dmSettings.customTemplateId!.trim().isNotEmpty;
    
    // If custom template, show custom template preview
    if (isCustomTemplate) {
      final customTemplateId = payload.dmSettings.customTemplateId!.trim();
      if (customTemplateId == 'lakshmee_v1') {
        return _buildLakshmeePreview();
      }
      // For other custom templates, show message
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          border: Border.all(
            color: AuthColors.info,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.description_outlined,
              size: 64,
              color: AuthColors.info,
            ),
            const SizedBox(height: 16),
            Text(
              'Custom Template: $customTemplateId',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AuthColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Preview is not available for this custom template.\nThe PDF will use the custom template when you print.',
              style: TextStyle(
                fontSize: 14,
                color: AuthColors.textSub,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    // Universal template preview
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

  /// Build Lakshmee template preview (lakshmee_v1)
  Widget _buildLakshmeePreview() {
    // Parse data similar to DmPrintData.fromMap
    final dmNumber = dmData['dmNumber'] as int? ??
        (dmData['dmNumber'] as num?)?.toInt() ??
        0;
    final deliveryDateData = dmData['deliveryDate'] ?? dmData['scheduledDate'];
    final deliveryDate = _parseDate(deliveryDateData);
    
    final clientName = dmData['clientName'] as String? ?? 'N/A';
    final clientPhone = dmData['clientPhone'] as String? ??
        dmData['clientPhoneNumber'] as String? ??
        dmData['customerNumber'] as String? ??
        'N/A';
    
    final vehicleNumber = dmData['vehicleNumber'] as String? ?? 'N/A';
    final driverName = dmData['driverName'] as String? ?? 'N/A';
    
    final itemsData = dmData['items'];
    final rawItems = itemsData is List
        ? itemsData
        : (itemsData != null ? [itemsData] : []);
    final firstItem = rawItems.isNotEmpty && rawItems.first is Map<String, dynamic>
        ? rawItems.first as Map<String, dynamic>
        : <String, dynamic>{};
    final productName = firstItem['productName'] as String? ??
        firstItem['name'] as String? ??
        'N/A';
    final quantity = (firstItem['fixedQuantityPerTrip'] as num?)?.toInt() ??
        (firstItem['totalQuantity'] as num?)?.toInt() ??
        (firstItem['quantity'] as num?)?.toInt() ??
        0;
    final unitPrice = (firstItem['unitPrice'] as num?)?.toDouble() ??
        (firstItem['price'] as num?)?.toDouble() ??
        0.0;
    
    double totalAmount = 0.0;
    final tripPricingData = dmData['tripPricing'];
    if (tripPricingData is Map<String, dynamic>) {
      totalAmount = (tripPricingData['total'] as num?)?.toDouble() ?? 0.0;
    }
    if (totalAmount == 0.0) {
      totalAmount = quantity * unitPrice;
    }
    
    // Handle paymentStatus - could be bool or string
    final paymentStatusValue = dmData['paymentStatus'];
    final paymentStatus = paymentStatusValue is bool
        ? paymentStatusValue
        : (paymentStatusValue is String
            ? paymentStatusValue.toLowerCase() == 'true' || paymentStatusValue.toLowerCase() == 'paid'
            : false);
    // Use paymentType from trip/dmData - if pay_later show "Pay Later", if pay_on_delivery show "Pay Now"
    final paymentType = dmData['paymentType'] as String?;
    String paymentMode = 'N/A';
    if (paymentType != null) {
      final lowerPaymentType = paymentType.toLowerCase();
      if (lowerPaymentType == 'pay_later') {
        paymentMode = 'Pay Later';
      } else if (lowerPaymentType == 'pay_on_delivery') {
        paymentMode = 'Pay Now';
      } else {
        paymentMode = paymentType;
      }
    } else {
      // Fallback to old logic if paymentType is not available
      final toAccount = dmData['toAccount'] as String?;
      final paySchedule = dmData['paySchedule'] as String?;
      if (paymentStatus && toAccount != null) {
        paymentMode = toAccount;
      } else if (paySchedule == 'POD') {
        paymentMode = 'Cash';
      } else if (paySchedule == 'PL') {
        paymentMode = 'Credit';
      } else if (paySchedule != null) {
        paymentMode = paySchedule;
      }
    }
    
    final paymentAccountName = payload.paymentAccount?['name'] as String?;
    final accountName = paymentAccountName ??
        (payload.dmSettings.header.name.isNotEmpty
            ? payload.dmSettings.header.name
            : 'Lakshmee Intelligent Technologies');
    
    final address = dmData['address'] as String?;
    final regionName = dmData['regionName'] as String?;
    final formattedAddress = '${address ?? "-"}, ${regionName ?? ""}'.trim();
    final displayAddress = (formattedAddress.isEmpty || formattedAddress == ',') ? 'N/A' : formattedAddress;
    
    // Get company info from DM settings
    final companyTitle = payload.dmSettings.header.name.isNotEmpty
        ? payload.dmSettings.header.name.toUpperCase()
        : 'LAKSHMEE INTELLIGENT TECHNOLOGIES';
    final companyAddress = payload.dmSettings.header.address.isNotEmpty
        ? payload.dmSettings.header.address
        : 'B-24/2, M.I.D.C., CHANDRAPUR - 442406';
    final companyPhone = payload.dmSettings.header.phone.isNotEmpty
        ? payload.dmSettings.header.phone
        : 'Ph: +91 8149448822 | +91 9420448822';
    final jurisdictionNote = payload.dmSettings.footer.customText?.isNotEmpty == true
        ? payload.dmSettings.footer.customText!
        : 'Note: Subject to Chandrapur Jurisdiction';
    
    // Format currency
    String formatCurrency(double amount) {
      return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
    }
    
    // Format date
    String formatDate(DateTime date) {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
    
    // Show QR code if available and payment display is QR code
    final showQrCode = payload.dmSettings.paymentDisplay == DmPaymentDisplay.qrCode;
    final qrCodeBytes = showQrCode ? payload.qrCodeBytes : null;
    
    // Build a single ticket widget (reusable for original and duplicate)
    Widget buildTicket({required bool isDuplicate}) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1),
          color: isDuplicate ? const Color(0xFFE0E0E0) : Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flag text
            Center(
              child: Text(
                '🚩 जय श्री राम 🚩',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Company branding header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                border: Border.all(color: const Color(0xFFBBBBBB), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Text(
                    companyTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companyAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    companyPhone,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Divider
            Container(
              height: 2,
              color: Colors.black,
            ),
            const SizedBox(height: 6),
            // Title row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isDuplicate ? '🚚 Delivery Memo (Duplicate)' : '🚚 Delivery Memo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'DM No. #$dmNumber',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          // Main content
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: QR Section
              if (qrCodeBytes != null && qrCodeBytes.isNotEmpty) ...[
                SizedBox(
                  width: 180,
                  child: Column(
                    children: [
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black, width: 3),
                          color: const Color(0xFFF8F8F8),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.memory(
                          qrCodeBytes,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        accountName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to pay ₹${formatCurrency(totalAmount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // Right column: Info + Table
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCCCCCC), width: 1),
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFFAFAFA),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Client: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Address: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: displayAddress),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Phone: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: clientPhone, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Date: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: formatDate(deliveryDate)),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Vehicle: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: vehicleNumber),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 14, color: Colors.black),
                                    children: [
                                      const TextSpan(text: 'Driver: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                      TextSpan(text: driverName),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Product table
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Column(
                        children: [
                          _buildLakshmeeTableRow('📦 Product', productName, isTotal: false),
                          _buildLakshmeeTableRow('🔢 Quantity', quantity.toString(), isTotal: false),
                          _buildLakshmeeTableRow('💰 Unit Price', '₹${formatCurrency(unitPrice)}', isTotal: false),
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Colors.black, width: 1)),
                            ),
                            child: _buildLakshmeeTableRow('🧾 Total', '₹${formatCurrency(totalAmount)}', isTotal: true),
                          ),
                          _buildLakshmeeTableRow('💳 Payment Mode', paymentMode, isTotal: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
            const SizedBox(height: 8),
            // Jurisdiction note
            Center(
              child: Text(
                jurisdictionNote,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            // Footer signatures
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Received By',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.black, width: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Authorized Signature',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 1,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.black, width: 1)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
    // Return both tickets with cut line divider - wrapped in SingleChildScrollView to prevent overflow
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // First ticket (Original)
          buildTicket(isDuplicate: false),
          // Cut line divider
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Container(
                  height: 1,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFF888888),
                        width: 1,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  child: CustomPaint(
                    painter: DashedLinePainter(),
                    size: const Size(double.infinity, 1),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '✂️ Cut Here',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF888888),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Second ticket (Duplicate)
          buildTicket(isDuplicate: true),
        ],
      ),
    );
  }

  Widget _buildLakshmeeTableRow(String label, String value, {required bool isTotal}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isTotal ? 3 : 2),
      decoration: isTotal
          ? const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black, width: 1),
              ),
            )
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFFCCCCCC),
                  width: 1,
                ),
              ),
            ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 15 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
