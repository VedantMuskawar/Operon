import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_models/core_models.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart' show generateLedgerPdf, LedgerRowData;
import 'package:dash_web/presentation/widgets/ledger_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Dialog that shows ledger as Flutter view first. Share = PNG capture; Print = deferred PDF.
/// Uses lazy-loading pattern: shows dialog immediately with loading state.
class LedgerPreviewDialog extends StatefulWidget {
  const LedgerPreviewDialog({
    super.key,
    required this.ledgerType,
    required this.entityName,
    required this.transactions,
    required this.openingBalance,
    required this.companyHeader,
    required this.startDate,
    required this.endDate,
    this.logoBytes,
    this.title,
  });

  final LedgerType ledgerType;
  final String entityName;
  final List<LedgerRowData> transactions;
  final double openingBalance;
  final DmHeaderSettings companyHeader;
  final DateTime startDate;
  final DateTime endDate;
  final Uint8List? logoBytes;
  final String? title;

  @override
  State<LedgerPreviewDialog> createState() => _LedgerPreviewDialogState();
}

class _LedgerPreviewDialogState extends State<LedgerPreviewDialog> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isGeneratingPdf = false;
  Uint8List? _cachedLogoBytes;

  @override
  void initState() {
    super.initState();
    _cachedLogoBytes = widget.logoBytes;
  }

  @override
  void dispose() {
    // Free up memory by nullifying Uint8List
    _cachedLogoBytes = null;
    super.dispose();
  }

  Future<void> _shareAsPng() async {
    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Could not capture document',
          isError: true,
        );
      }
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;
      final bytes = byteData.buffer.asUint8List();
      final name = 'Ledger-${widget.entityName.replaceAll(RegExp(r'[^\w\s-]'), '')}-${widget.startDate.millisecondsSinceEpoch}.png';
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
        text: 'Ledger ${widget.entityName}',
      );
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to share: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _onPrint() async {
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await generateLedgerPdf(
        ledgerType: widget.ledgerType,
        entityName: widget.entityName,
        transactions: widget.transactions,
        openingBalance: widget.openingBalance,
        companyHeader: widget.companyHeader,
        startDate: widget.startDate,
        endDate: widget.endDate,
        logoBytes: _cachedLogoBytes,
      );
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      Navigator.of(context).pop();
      await OperonPdfPreviewModal.show(
        context: context,
        pdfBytes: pdfBytes,
        title: widget.title ?? 'Ledger of ${widget.entityName}',
        pdfFileName: 'ledger-${widget.entityName.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        DashSnackbar.show(
          context,
          message: 'Failed to generate PDF: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AuthColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title ?? 'Ledger - ${widget.entityName}',
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: AspectRatio(
                      aspectRatio: 210 / 297,
                      child: LedgerDocument(
                        ledgerType: widget.ledgerType,
                        entityName: widget.entityName,
                        transactions: widget.transactions,
                        openingBalance: widget.openingBalance,
                        companyHeader: widget.companyHeader,
                        startDate: widget.startDate,
                        endDate: widget.endDate,
                        logoBytes: _cachedLogoBytes,
                      ),
                    ),
                  ),
                ),
              ),
              if (_isGeneratingPdf)
                const LinearProgressIndicator(color: AuthColors.info),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Share',
                    onPressed: _isGeneratingPdf ? null : _shareAsPng,
                    variant: DashButtonVariant.outlined,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Print',
                    onPressed: _isGeneratingPdf ? null : _onPrint,
                  ),
                  const SizedBox(width: 12),
                  DashButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
