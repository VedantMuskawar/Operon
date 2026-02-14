import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:dash_mobile/data/repositories/dm_settings_repository.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/widgets/fuel_ledger_document.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Dialog to generate Fuel Ledger PDF: choose voucher range or date range,
/// then preview/print/share PDF.
class FuelLedgerPdfDialog extends StatefulWidget {
  const FuelLedgerPdfDialog({
    super.key,
    required this.vendor,
    required this.organizationId,
    required this.transactionsRepository,
    required this.dmSettingsRepository,
    required this.dmPrintService,
  });

  final Vendor vendor;
  final String organizationId;
  final TransactionsRepository transactionsRepository;
  final DmSettingsRepository dmSettingsRepository;
  final DmPrintService dmPrintService;

  @override
  State<FuelLedgerPdfDialog> createState() => _FuelLedgerPdfDialogState();
}

class _FuelLedgerPdfDialogState extends State<FuelLedgerPdfDialog> {
  String _rangeMode = 'voucherRange'; // 'voucherRange' | 'dateRange'
  final _fromVoucherController = TextEditingController();
  final _toVoucherController = TextEditingController();
  DateTime? _dateFrom;
  DateTime? _dateTo;
  bool _isLoading = false;
  String? _errorMessage;

  List<FuelLedgerRow>? _viewRows;
  double _viewTotal = 0;
  String? _viewPaymentMode;
  DateTime? _viewPaymentDate;
  DmHeaderSettings? _viewCompanyHeader;
  Uint8List? _viewLogoBytes;
  bool _isGeneratingPdf = false;
  String? _actionError;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void dispose() {
    _fromVoucherController.dispose();
    _toVoucherController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      DateTime? startDate;
      DateTime? endDate;

      if (_rangeMode == 'dateRange') {
        if (_dateFrom == null || _dateTo == null) {
          setState(() {
            _errorMessage = 'Select from and to date';
            _isLoading = false;
          });
          return;
        }
        startDate = DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);
        endDate = DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day);
      }

      final transactions =
          await widget.transactionsRepository.getFuelVendorPurchases(
        organizationId: widget.organizationId,
        vendorId: widget.vendor.id,
        startDate: startDate,
        endDate: endDate,
        limit: 2000,
      );

      List<Transaction> filtered;
      if (_rangeMode == 'voucherRange') {
        final fromStr = _fromVoucherController.text.trim();
        final toStr = _toVoucherController.text.trim();
        if (fromStr.isEmpty || toStr.isEmpty) {
          setState(() {
            _errorMessage = 'Enter voucher from and to';
            _isLoading = false;
          });
          return;
        }
        filtered = transactions.where((tx) {
          final v = tx.referenceNumber ??
              tx.metadata?['voucherNumber']?.toString() ??
              '';
          if (v.isEmpty) return false;
          return v.compareTo(fromStr) >= 0 && v.compareTo(toStr) <= 0;
        }).toList();
      } else {
        filtered = transactions;
      }

      filtered.sort((a, b) {
        final ad = a.createdAt ?? DateTime(1970);
        final bd = b.createdAt ?? DateTime(1970);
        return ad.compareTo(bd);
      });

      if (filtered.isEmpty) {
        setState(() {
          _errorMessage = 'No transactions in the selected range';
          _isLoading = false;
        });
        return;
      }

      final dmSettings = await widget.dmSettingsRepository
          .fetchDmSettings(widget.organizationId);
      if (dmSettings == null) {
        setState(() {
          _errorMessage = 'DM Settings not found. Configure DM Settings first.';
          _isLoading = false;
        });
        return;
      }

      final logoBytes = await widget.dmPrintService
          .loadImageBytes(dmSettings.header.logoImageUrl);

      final rows = filtered.map((tx) {
        final voucher = tx.referenceNumber ??
            tx.metadata?['voucherNumber']?.toString() ??
            '';
        final date = tx.createdAt ?? DateTime.now();
        final vehicleNo = tx.metadata?['vehicleNumber']?.toString() ?? '';
        return FuelLedgerRow(
          voucher: voucher,
          date: date,
          amount: tx.amount,
          vehicleNo: vehicleNo,
        );
      }).toList();

      final total = rows.fold<double>(0, (s, r) => s + r.amount);
      final modes = filtered
          .map((tx) => tx.paymentAccountType ?? '')
          .where((s) => s.isNotEmpty)
          .toSet();
      final paymentMode = modes.length == 1
          ? (modes.single.isEmpty ? null : modes.single)
          : 'Various';
      final paymentDate = filtered.last.createdAt;

      if (mounted) {
        setState(() {
          _viewRows = rows;
          _viewTotal = total;
          _viewPaymentMode = paymentMode;
          _viewPaymentDate = paymentDate;
          _viewCompanyHeader = dmSettings.header;
          _viewLogoBytes = logoBytes;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _shareAsPng() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) {
        DashSnackbar.show(context, message: 'Could not capture', isError: true);
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/Fuel-Ledger-${widget.vendor.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],
          text: 'Fuel Ledger ${widget.vendor.name}');
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(context,
            message: 'Failed to share: $e', isError: true);
      }
    }
  }

  Future<void> _generatePdfThenPrint() async {
    if (_viewRows == null || _viewCompanyHeader == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await generateFuelLedgerPdf(
        companyHeader: _viewCompanyHeader!,
        vendorName: widget.vendor.name,
        rows: _viewRows!,
        total: _viewTotal,
        paymentMode: _viewPaymentMode,
        paymentDate: _viewPaymentDate,
        logoBytes: _viewLogoBytes,
      );
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      await Printing.layoutPdf(onLayout: (_) async => pdfBytes);
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(context, message: 'Print dialog opened');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        DashSnackbar.show(context,
            message: 'Failed to print: $e', isError: true);
      }
    }
  }

  Future<void> _generatePdfThenShare() async {
    if (_viewRows == null || _viewCompanyHeader == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await generateFuelLedgerPdf(
        companyHeader: _viewCompanyHeader!,
        vendorName: widget.vendor.name,
        rows: _viewRows!,
        total: _viewTotal,
        paymentMode: _viewPaymentMode,
        paymentDate: _viewPaymentDate,
        logoBytes: _viewLogoBytes,
      );
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'Fuel-Ledger-${widget.vendor.name.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf',
      );
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(context, message: 'PDF shared');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        DashSnackbar.show(context,
            message: 'Failed to share PDF: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_viewRows != null && _viewCompanyHeader != null) {
      return _buildResultDialog();
    }
    return _buildRangeDialog();
  }

  Widget _buildRangeDialog() {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: const Text(
        'Fuel Ledger PDF',
        style: TextStyle(color: AuthColors.textMain, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select range',
                style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              RadioGroup<String>(
                groupValue: _rangeMode,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _rangeMode = value);
                  }
                },
                child: const Column(
                  children: [
                    RadioListTile<String>(
                      title: Text(
                        'Voucher range',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                      value: 'voucherRange',
                      activeColor: AuthColors.primary,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text(
                        'Date range',
                        style: TextStyle(
                          color: AuthColors.textSub,
                          fontSize: 14,
                        ),
                      ),
                      value: 'dateRange',
                      activeColor: AuthColors.primary,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.paddingLG),
              if (_rangeMode == 'voucherRange') ...[
                TextField(
                  controller: _fromVoucherController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: InputDecoration(
                    labelText: 'From voucher',
                    labelStyle: const TextStyle(color: AuthColors.textSub),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AuthColors.textSubWithOpacity(0.38)),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))
                  ],
                ),
                const SizedBox(height: AppSpacing.paddingMD),
                TextField(
                  controller: _toVoucherController,
                  style: const TextStyle(color: AuthColors.textMain),
                  decoration: InputDecoration(
                    labelText: 'To voucher',
                    labelStyle: const TextStyle(color: AuthColors.textSub),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                          color: AuthColors.textSubWithOpacity(0.38)),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'[\n\r]'))
                  ],
                ),
              ] else ...[
                ListTile(
                  title: const Text('From date',
                      style:
                          TextStyle(color: AuthColors.textSub, fontSize: 12)),
                  subtitle: Text(
                    _dateFrom != null
                        ? '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}'
                        : 'Tap to select',
                    style: const TextStyle(color: AuthColors.textMain),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateFrom ??
                          DateTime.now().subtract(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dateFrom = d);
                  },
                ),
                ListTile(
                  title: const Text('To date',
                      style:
                          TextStyle(color: AuthColors.textSub, fontSize: 12)),
                  subtitle: Text(
                    _dateTo != null
                        ? '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}'
                        : 'Tap to select',
                    style: const TextStyle(color: AuthColors.textMain),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _dateTo ?? DateTime.now(),
                      firstDate: _dateFrom ?? DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _dateTo = d);
                  },
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.paddingMD),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AuthColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child:
              const Text('Cancel', style: TextStyle(color: AuthColors.textSub)),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _generate,
          style: FilledButton.styleFrom(backgroundColor: AuthColors.primary),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AuthColors.textMain),
                )
              : const Text('Generate',
                  style: TextStyle(color: AuthColors.textMain)),
        ),
      ],
    );
  }

  Widget _buildResultDialog() {
    return AlertDialog(
      backgroundColor: AuthColors.surface,
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: AuthColors.info, size: 20),
          const SizedBox(width: AppSpacing.paddingSM),
          Expanded(
            child: Text(
              'Fuel Ledger - ${widget.vendor.name}',
              style: const TextStyle(
                color: AuthColors.textMain,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: AspectRatio(
                  aspectRatio: 210 / 297,
                  child: FuelLedgerDocument(
                    companyHeader: _viewCompanyHeader!,
                    vendorName: widget.vendor.name,
                    rows: _viewRows!,
                    total: _viewTotal,
                    paymentMode: _viewPaymentMode,
                    paymentDate: _viewPaymentDate,
                    logoBytes: _viewLogoBytes,
                  ),
                ),
              ),
              if (_isGeneratingPdf)
                const LinearProgressIndicator(color: AuthColors.info),
              if (_actionError != null) ...[
                const SizedBox(height: AppSpacing.paddingMD),
                Text(
                  _actionError!,
                  style: const TextStyle(color: AuthColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isGeneratingPdf ? null : () => Navigator.of(context).pop(),
          child:
              const Text('Close', style: TextStyle(color: AuthColors.textSub)),
        ),
        DashButton(
          label: 'Share',
          onPressed: _isGeneratingPdf ? null : _shareAsPng,
          icon: Icons.share,
          variant: DashButtonVariant.outlined,
        ),
        DashButton(
          label: 'Print',
          onPressed: _isGeneratingPdf ? null : _generatePdfThenPrint,
          icon: Icons.print,
        ),
        DashButton(
          label: 'Share PDF',
          onPressed: _isGeneratingPdf ? null : _generatePdfThenShare,
          icon: Icons.picture_as_pdf,
        ),
      ],
    );
  }
}
