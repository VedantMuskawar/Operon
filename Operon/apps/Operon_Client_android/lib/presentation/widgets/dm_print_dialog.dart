import 'dart:io';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/dm_print_service.dart';
import 'package:dash_mobile/presentation/widgets/delivery_memo_document.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Shows DM content as a native Flutter view first (no PDF until Print).
/// Share to WhatsApp uses PNG capture; Print generates PDF on demand.
class DmPrintDialog extends StatefulWidget {
  const DmPrintDialog({
    super.key,
    required this.dmPrintService,
    required this.organizationId,
    required this.dmData,
    required this.dmNumber,
  });

  final DmPrintService dmPrintService;
  final String organizationId;
  final Map<String, dynamic> dmData;
  final int dmNumber;

  @override
  State<DmPrintDialog> createState() => _DmPrintDialogState();
}

class _DmPrintDialogState extends State<DmPrintDialog> {
  bool _isLoadingView = true;
  bool _hasError = false;
  String? _errorMessage;
  DmViewPayload? _payload;
  bool _isGeneratingPdf = false;
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadViewData();
  }

  Future<void> _loadViewData() async {
    try {
      final payload = await widget.dmPrintService.loadDmViewData(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _isLoadingView = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingView = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        DashSnackbar.show(
          context,
          message: 'Failed to load DM: $e',
          isError: true,
        );
      }
    }
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
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/DM-${widget.dmNumber}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'DM-${widget.dmNumber}',
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
    if (_payload == null) return;
    setState(() => _isGeneratingPdf = true);
    try {
      final pdfBytes = await widget.dmPrintService.generatePdfBytes(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
        viewPayload: _payload,
      );
      if (!mounted) return;
      setState(() => _isGeneratingPdf = false);
      Navigator.of(context).pop();
      await OperonPdfPreviewModal.show(
        context: context,
        pdfBytes: pdfBytes,
        title: 'DM-${widget.dmNumber}',
        pdfFileName: 'DM-${widget.dmNumber}.pdf',
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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.paddingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoadingView) ...[
              const CircularProgressIndicator(color: AuthColors.info),
              const SizedBox(height: AppSpacing.paddingXL),
              Text(
                'Loading DM-${widget.dmNumber}...',
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                ),
              ),
            ] else if (_hasError) ...[
              const Icon(Icons.error_outline, color: AuthColors.error, size: 48),
              const SizedBox(height: AppSpacing.paddingLG),
              Text(
                _errorMessage ?? 'Failed to load',
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.paddingXL),
              DashButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                variant: DashButtonVariant.outlined,
              ),
            ] else if (_payload != null) ...[
              Text(
                'DM-${widget.dmNumber}',
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.paddingMD),
              Flexible(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.85,
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                    ),
                    child: AspectRatio(
                      aspectRatio: 210 / 297,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: DeliveryMemoDocument(
                          dmData: widget.dmData,
                          payload: _payload!,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (_isGeneratingPdf)
                const LinearProgressIndicator(color: AuthColors.info),
              const SizedBox(height: AppSpacing.paddingLG),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DashButton(
                    label: 'Share',
                    onPressed: _isGeneratingPdf ? null : _shareAsPng,
                    variant: DashButtonVariant.outlined,
                  ),
                  const SizedBox(width: AppSpacing.paddingMD),
                  DashButton(
                    label: 'Print',
                    onPressed: _isGeneratingPdf ? null : _onPrint,
                  ),
                  const SizedBox(width: AppSpacing.paddingMD),
                  DashButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    variant: DashButtonVariant.outlined,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
