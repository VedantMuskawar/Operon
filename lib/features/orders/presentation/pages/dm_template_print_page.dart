import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../contexts/organization_context.dart';
import '../../../../core/models/scheduled_order.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../organization/presentation/utils/dm_template_exporter.dart';
import '../../../vehicle/models/vehicle.dart';

class DmTemplatePrintPage extends StatefulWidget {
  const DmTemplatePrintPage({
    super.key,
    required this.schedule,
    required this.organizationId,
    this.vehicle,
  });

  final ScheduledOrder schedule;
  final String organizationId;
  final Vehicle? vehicle;

  @override
  State<DmTemplatePrintPage> createState() => _DmTemplatePrintPageState();
}

class _DmTemplatePrintPageState extends State<DmTemplatePrintPage> {
  final GlobalKey _memoKey = GlobalKey(debugLabel: 'dmA5MemoOriginal');
  final GlobalKey _duplicateMemoKey =
      GlobalKey(debugLabel: 'dmA5MemoDuplicate');
  bool _isExporting = false;

  ScheduledOrder get _schedule => widget.schedule;
  Vehicle? get _vehicle => widget.vehicle;

  @override
  Widget build(BuildContext context) {
    final dmLabel =
        _schedule.dmNumber != null ? 'DM-${_schedule.dmNumber}' : 'Delivery Memo';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(dmLabel),
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _onPrintPressed,
              icon: const Icon(Icons.print_outlined),
              label: const Text('Print'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(AppTheme.getResponsivePadding(context)),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: AppTheme.spacingXl),
          Text(
            'Original Memo',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Center(
            child: RepaintBoundary(
              key: _memoKey,
              child: _buildMemoLayout(context, invertColors: false),
            ),
          ),
            const SizedBox(height: AppTheme.spacingXl),
            Text(
            'Duplicate (Inverted)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
          Center(
            child: RepaintBoundary(
              key: _duplicateMemoKey,
              child: _buildMemoLayout(context, invertColors: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final schedule = _schedule;
    final vehicle = _vehicle;

    const borderColor = Color(0xFFBEBEBE);
    const labelStyle = TextStyle(
      color: Colors.black54,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.7,
    );
    const valueStyle = TextStyle(
      color: Colors.black87,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    Widget buildItem(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: labelStyle),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '—' : value, style: valueStyle),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppTheme.spacingLg,
            runSpacing: AppTheme.spacingMd,
            children: [
              buildItem(
                'Client',
                schedule.clientName ?? schedule.clientPhone ?? 'Not specified',
              ),
              buildItem('Order', schedule.orderId),
              buildItem(
                'Scheduled Date',
                _formatFullDate(schedule.scheduledDate),
              ),
              buildItem('Quantity', '${schedule.quantity}'),
              buildItem('Amount', _formatMoney(schedule.totalAmount)),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Wrap(
            spacing: AppTheme.spacingLg,
            runSpacing: AppTheme.spacingMd,
            children: [
              if (vehicle != null) buildItem('Vehicle', vehicle.vehicleNo),
              if (_schedule.driverName != null ||
                  vehicle?.assignedDriverName != null)
                buildItem(
                  'Driver',
                  _schedule.driverName ?? vehicle?.assignedDriverName ?? '',
                ),
              if (_schedule.driverPhone != null ||
                  vehicle?.assignedDriverContact != null)
                buildItem(
                  'Driver Contact',
                  _schedule.driverPhone ?? vehicle?.assignedDriverContact ?? '',
                ),
              if (schedule.dmGeneratedAt != null)
                buildItem(
                  'Generated At',
                  _formatDateTime(schedule.dmGeneratedAt!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoLayout(
    BuildContext context, {
    required bool invertColors,
  }) {
    final schedule = _schedule;
    final vehicle = _vehicle;
    final orgContext = _maybeOrgContext(context);
    final orgData = orgContext?.currentOrganization ?? const <String, dynamic>{};
    final palette = _MemoPalette.fromInversion(invertColors);

    final organizationName =
        _firstNonEmpty([orgData['orgName'], orgContext?.organizationName]) ??
            'Organization';
    final organizationAddress =
        _buildOrganizationAddress(orgData) ?? _formatClientAddress(schedule);
    final organizationPhones = _collectPhones(orgData);

    final dmNumberText =
        schedule.dmNumber != null ? '#${schedule.dmNumber}' : 'Pending';
    final dmDate =
        _formatFullDate(schedule.dmGeneratedAt ?? schedule.scheduledDate);
    final clientName = schedule.clientName ?? '—';
    final clientAddress = _formatClientAddress(schedule);
    final clientPhone = schedule.clientPhone ?? '—';
    final vehicleNumber = vehicle?.vehicleNo ?? schedule.vehicleId;
    final driverName = schedule.driverName ?? vehicle?.assignedDriverName ?? '';
    final driverPhone =
        schedule.driverPhone ?? vehicle?.assignedDriverContact ?? '';
    final paymentMode =
        schedule.paymentType.isNotEmpty ? schedule.paymentType : '—';
    final productDescription = _buildProductDescription(schedule);
    final totalAmount = _formatMoney(schedule.totalAmount);
    final unitPrice =
        schedule.unitPrice > 0 ? _formatMoney(schedule.unitPrice) : '—';
    final quantity = '${schedule.quantity}';
    final noteSubject =
        schedule.orderRegion.isNotEmpty ? schedule.orderRegion : organizationName;
    final noteText = 'Note: Subject to $noteSubject Jurisdiction';
    final qrCaption = 'Scan to pay $totalAmount';

    return Container(
      color: invertColors ? const Color(0xFF101010) : const Color(0xFFE5E7EB),
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 880,
        child: AspectRatio(
          aspectRatio: 210 / 148,
          child: Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.frameBorder, width: 2),
            ),
            child: Stack(
      children: [
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: CustomPaint(
                      painter: _MemoWatermarkPainter(palette.watermark),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildMemoHeader(
                        palette: palette,
                        organizationName: organizationName,
                        organizationAddress: organizationAddress,
                        organizationPhones: organizationPhones,
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: palette.divider),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: _buildMemoLeftColumn(
                                palette: palette,
                                organizationName: organizationName,
                                qrCaption: qrCaption,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 8,
                              child: _buildMemoRightColumn(
                                palette: palette,
                                dmNumber: dmNumberText,
                                dmDate: dmDate,
                                clientName: clientName,
                                clientAddress: clientAddress,
                                clientPhone: clientPhone,
                                vehicleNumber: vehicleNumber,
                                driverName: driverName,
                                driverPhone: driverPhone,
                                productDescription: productDescription,
                                totalAmount: totalAmount,
                                quantity: quantity,
                                unitPrice: unitPrice,
                                paymentMode: paymentMode,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
        Text(
                        noteText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
            fontSize: 11,
                          color: palette.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SignatureLine(label: 'Received By', palette: palette),
                          _SignatureLine(
                            label: 'Authorized Signature',
                            palette: palette,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoHeader({
    required _MemoPalette palette,
    required String organizationName,
    required String organizationAddress,
    required List<String> organizationPhones,
  }) {
    final phoneLine = organizationPhones.isEmpty
        ? null
        : 'Ph: ${organizationPhones.join(' | ')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'जय श्री राम',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.headlineAccent,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          decoration: BoxDecoration(
            color: palette.headerBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: palette.headerBorder, width: 1.4),
          ),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
        children: [
              Text(
                organizationName.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: palette.textPrimary,
                ),
              ),
              if (organizationAddress.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
                  organizationAddress,
              textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                    color: palette.textPrimary,
                  ),
                ),
              ],
              if (phoneLine != null) ...[
                const SizedBox(height: 4),
                Text(
                  phoneLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.4,
                    color: palette.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onPrintPressed() async {
    bool includeDuplicate = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Print Delivery Memo'),
              content: CheckboxListTile(
                value: includeDuplicate,
                onChanged: (value) {
                  setState(() => includeDuplicate = value ?? false);
                },
                title: const Text('Print duplicate copy'),
                subtitle:
                    const Text('Duplicate will use the inverted black/white layout.'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(includeDuplicate),
                  child: const Text('Print'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    await _performPrint(includeDuplicate: result);
  }

  Future<void> _performPrint({required bool includeDuplicate}) async {
    setState(() => _isExporting = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      final originalBytes = await _captureMemo(_memoKey);
      await printDmTemplate(
        originalBytes,
        fileName: 'dm-original-$timestamp.png',
      );

      if (includeDuplicate) {
        final duplicateBytes = await _captureMemo(_duplicateMemoKey);
        await printDmTemplate(
          duplicateBytes,
          fileName: 'dm-duplicate-$timestamp.png',
        );
      }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            content: Text(
              includeDuplicate
                  ? 'Print preview opened for original and duplicate memos.'
                  : 'Print preview opened for original memo.',
            ),
            ),
          );
        }
    } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Unable to print memo: $error'),
            ),
          );
        }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Widget _buildMemoLeftColumn({
    required _MemoPalette palette,
    required String organizationName,
    required String qrCaption,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panelBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: palette.chipBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.panelBorder.withOpacity(0.3)),
            ),
            child: Text(
              'Delivery Memo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.chipText,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.panelBorder, width: 1.2),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.qr_code_2,
                size: 110,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            organizationName,
              textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
                fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            qrCaption,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: palette.textSecondary,
            ),
          ),
        ],
        ),
      );
    }

  Widget _buildMemoRightColumn({
    required _MemoPalette palette,
    required String dmNumber,
    required String dmDate,
    required String clientName,
    required String clientAddress,
    required String clientPhone,
    required String vehicleNumber,
    required String driverName,
    required String driverPhone,
    required String productDescription,
    required String totalAmount,
    required String quantity,
    required String unitPrice,
    required String paymentMode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoSummaryRow(
          palette: palette,
          clientName: clientName,
          clientAddress: clientAddress,
          clientPhone: clientPhone,
          dmNumber: dmNumber,
          dmDate: dmDate,
          vehicleNumber: vehicleNumber,
          driverName: driverName,
          driverPhone: driverPhone,
        ),
        const SizedBox(height: 12),
        _buildProductsTable(
          palette: palette,
          productDescription: productDescription,
          quantity: quantity,
          unitPrice: unitPrice,
        ),
        const SizedBox(height: 10),
        _buildTotalCard(palette, totalAmount),
        const SizedBox(height: 8),
        _buildPaymentModeCard(palette, paymentMode),
      ],
    );
  }

  Widget _buildInfoSummaryRow({
    required _MemoPalette palette,
    required String clientName,
    required String clientAddress,
    required String clientPhone,
    required String dmNumber,
    required String dmDate,
    required String vehicleNumber,
    required String driverName,
    required String driverPhone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panelBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLabelValue(
                  palette: palette,
                  label: 'Client',
                  value: clientName,
                  emphasizeValue: true,
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 6),
                _InfoLabelValue(
                  palette: palette,
                  label: 'Address',
                  value: clientAddress,
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 6),
                _InfoLabelValue(
                  palette: palette,
                  label: 'Phone',
                  value: clientPhone,
                  icon: Icons.call_outlined,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 72,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: palette.divider,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLabelValue(
                  palette: palette,
                  label: 'DM No.',
                  value: dmNumber,
                  alignRight: true,
                  emphasizeValue: true,
                  icon: Icons.confirmation_number_outlined,
                ),
                const SizedBox(height: 6),
                _InfoLabelValue(
                  palette: palette,
                  label: 'Date',
                  value: dmDate,
                  alignRight: true,
                  icon: Icons.event_outlined,
                ),
                const SizedBox(height: 6),
                _InfoLabelValue(
                  palette: palette,
                  label: 'Vehicle',
                  value: vehicleNumber,
                  alignRight: true,
                  icon: Icons.local_shipping_outlined,
                ),
                if (driverName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoLabelValue(
                    palette: palette,
                    label: 'Driver',
                    value: driverName,
                    alignRight: true,
                    icon: Icons.badge_outlined,
                  ),
                ],
                if (driverPhone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoLabelValue(
                    palette: palette,
                    label: 'Driver Phone',
                    value: driverPhone,
                    alignRight: true,
                    icon: Icons.phone_android_outlined,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTable({
    required _MemoPalette palette,
    required String productDescription,
    required String quantity,
    required String unitPrice,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.panelBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorder, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: palette.tableHeaderBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Text(
                    'Product',
                    style: TextStyle(
                      color: palette.tableHeaderText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Quantity',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.tableHeaderText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Unit Price',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.tableHeaderText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildProductRow(
            palette: palette,
            description: productDescription,
            quantity: quantity,
            unitPrice: unitPrice,
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow({
    required _MemoPalette palette,
    required String description,
    required String quantity,
    required String unitPrice,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.tableRowBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    description,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              quantity,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              unitPrice,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard(_MemoPalette palette, String total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: palette.totalBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 18,
                color: palette.totalLabel,
              ),
              const SizedBox(width: 8),
              Text(
                'Total',
                style: TextStyle(
                  color: palette.totalLabel,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          Text(
            total,
            style: TextStyle(
              color: palette.totalValue,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentModeCard(_MemoPalette palette, String paymentMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: palette.paymentBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.panelBorder.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.credit_card_outlined,
                size: 16,
                color: palette.paymentLabel,
              ),
              const SizedBox(width: 6),
              Text(
                'Payment Mode',
                style: TextStyle(
                  color: palette.paymentLabel,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          Text(
            paymentMode.isEmpty ? '—' : paymentMode,
            style: TextStyle(
              color: palette.paymentValue,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
            ),
          );
        }

  Future<Uint8List> _captureMemo(GlobalKey key) async {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Memo is not ready yet. Please try again in a moment.');
    }

    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      throw Exception('Unable to capture memo.');
    }
    return byteData.buffer.asUint8List();
  }

  OrganizationContext? _maybeOrgContext(BuildContext context) {
    try {
      return context.organizationContext;
    } catch (_) {
      return null;
    }
  }

  String? _buildOrganizationAddress(Map<String, dynamic> orgData) {
    final keys = [
      'address',
      'addressLine1',
      'addressLine2',
      'city',
      'state',
      'district',
      'pincode',
      'zip',
      'region',
    ];

    final values = <String>[];
    for (final key in keys) {
      final value = orgData[key];
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim());
      }
    }

    if (values.isEmpty) {
      return null;
    }

    return values.join(', ');
  }

  List<String> _collectPhones(Map<String, dynamic> orgData) {
    final keys = [
      'phone',
      'phoneNo',
      'phone1',
      'phone2',
      'contactNumber',
      'contactNo',
      'primaryPhone',
      'secondaryPhone',
      'mobile',
      'alternatePhone',
    ];

    final values = <String>{};
    for (final key in keys) {
      final value = orgData[key];
      if (value is String && value.trim().isNotEmpty) {
        values.add(value.trim());
      }
    }
    return values.toList();
  }

  String _formatClientAddress(ScheduledOrder schedule) {
    final parts = [
      if (schedule.orderCity.isNotEmpty) schedule.orderCity,
      if (schedule.orderRegion.isNotEmpty) schedule.orderRegion,
    ];
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _buildProductDescription(ScheduledOrder schedule) {
    final productNames = schedule.productNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (productNames.isEmpty) {
      return 'Delivery Item';
    }
    return productNames.join(', ');
  }

  String _formatMoney(double value) {
    final isNegative = value < 0;
    final absolute = value.abs();
    final integerPart = absolute.floor();
    final fractionPart = absolute - integerPart;

    final digits = integerPart.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }

    var formatted = buffer.toString();

    if (fractionPart > 0) {
      final decimals = fractionPart.toStringAsFixed(2);
      var decimalPart = decimals.substring(decimals.indexOf('.'));
      decimalPart = decimalPart.replaceFirst(RegExp(r'0+$'), '');
      if (decimalPart == '.') {
        decimalPart = '';
      }
      formatted += decimalPart;
    }

    final sign = isNegative ? '-' : '';
    return '₹$sign$formatted';
  }

  String _formatFullDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    return '$day $month $year';
  }

  String _formatDateTime(DateTime date) {
    final formattedDate = _formatFullDate(date);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$formattedDate • $hour:$minute $period';
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

class _SignatureLine extends StatelessWidget {
  const _SignatureLine({
    required this.label,
    required this.palette,
  });

  final String label;
  final _MemoPalette palette;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 6),
            color: palette.signatureLine,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: palette.signatureLabel,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLabelValue extends StatelessWidget {
  const _InfoLabelValue({
    required this.palette,
    required this.label,
    required this.value,
    this.alignRight = false,
    this.emphasizeValue = false,
    this.icon,
  });

  final _MemoPalette palette;
  final String label;
  final String value;
  final bool alignRight;
  final bool emphasizeValue;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 11.5,
      color: palette.textSecondary,
      fontWeight: FontWeight.w700,
    );

    final valueStyle = TextStyle(
      fontSize: emphasizeValue ? 14.5 : 13,
      color: palette.textPrimary,
      fontWeight: emphasizeValue ? FontWeight.w700 : FontWeight.w600,
    );

    final labelWidgets = <Widget>[
      if (icon != null)
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Icon(
            icon,
            size: 16,
            color: palette.textSecondary,
          ),
        ),
      Text('${label.toUpperCase()}:', style: labelStyle),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: labelWidgets,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: valueStyle,
          ),
        ),
      ],
    );
  }
}

class _MemoPalette {
  const _MemoPalette({
    required this.background,
    required this.frameBorder,
    required this.headerBackground,
    required this.headerBorder,
    required this.headlineAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.panelBackground,
    required this.panelBorder,
    required this.chipBackground,
    required this.chipText,
    required this.divider,
    required this.tableHeaderBackground,
    required this.tableHeaderText,
    required this.tableRowBorder,
    required this.totalBackground,
    required this.totalLabel,
    required this.totalValue,
    required this.paymentBackground,
    required this.paymentLabel,
    required this.paymentValue,
    required this.signatureLine,
    required this.signatureLabel,
    required this.watermark,
  });

  final Color background;
  final Color frameBorder;
  final Color headerBackground;
  final Color headerBorder;
  final Color headlineAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color panelBackground;
  final Color panelBorder;
  final Color chipBackground;
  final Color chipText;
  final Color divider;
  final Color tableHeaderBackground;
  final Color tableHeaderText;
  final Color tableRowBorder;
  final Color totalBackground;
  final Color totalLabel;
  final Color totalValue;
  final Color paymentBackground;
  final Color paymentLabel;
  final Color paymentValue;
  final Color signatureLine;
  final Color signatureLabel;
  final Color watermark;

  factory _MemoPalette.fromInversion(bool invert) {
    if (!invert) {
      return _MemoPalette(
        background: Colors.white,
        frameBorder: Colors.black87,
        headerBackground: const Color(0xFFF3F3F3),
        headerBorder: Colors.black87,
        headlineAccent: Colors.black87,
        textPrimary: Colors.black87,
        textSecondary: Colors.black54,
        panelBackground: Colors.white,
        panelBorder: Colors.black87,
        chipBackground: const Color(0xFFF5F5F5),
        chipText: Colors.black87,
        divider: Colors.black26,
        tableHeaderBackground: const Color(0xFFE7E7E7),
        tableHeaderText: Colors.black87,
        tableRowBorder: Colors.black26,
        totalBackground: Colors.black87,
        totalLabel: Colors.white70,
        totalValue: Colors.white,
        paymentBackground: const Color(0xFFF5F5F5),
        paymentLabel: Colors.black54,
        paymentValue: Colors.black87,
        signatureLine: Colors.black54,
        signatureLabel: Colors.black87,
        watermark: Colors.black.withOpacity(0.05),
      );
    }

    return _MemoPalette(
      background: const Color(0xFF0E0E0E),
      frameBorder: Colors.white70,
      headerBackground: const Color(0xFF151515),
      headerBorder: Colors.white70,
      headlineAccent: Colors.white,
      textPrimary: Colors.white,
      textSecondary: Colors.white70,
      panelBackground: const Color(0xFF111111),
      panelBorder: Colors.white60,
      chipBackground: const Color(0xFF1A1A1A),
      chipText: Colors.white,
      divider: Colors.white24,
      tableHeaderBackground: const Color(0xFF1F1F1F),
      tableHeaderText: Colors.white,
      tableRowBorder: Colors.white24,
      totalBackground: Colors.white,
      totalLabel: Colors.black54,
      totalValue: Colors.black,
      paymentBackground: const Color(0xFF1A1A1A),
      paymentLabel: Colors.white70,
      paymentValue: Colors.white,
      signatureLine: Colors.white70,
      signatureLabel: Colors.white,
      watermark: Colors.white.withOpacity(0.05),
    );
  }
}

class _MemoWatermarkPainter extends CustomPainter {
  const _MemoWatermarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.45;

    final circlePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.02;
    canvas.drawCircle(center, radius, circlePaint);

    final rect = Rect.fromCenter(
      center: center,
      width: size.shortestSide * 0.55,
      height: size.shortestSide * 0.22,
    );
    final rectPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.018;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide * 0.025)),
      rectPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

