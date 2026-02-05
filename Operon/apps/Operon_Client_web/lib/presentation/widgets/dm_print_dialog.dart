import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/presentation/widgets/delivery_memo_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Shows DM content as a native Flutter view first (no PDF until Print).
/// Share uses PNG capture; Print generates PDF on demand.
/// Used by Schedule Tile, Client Ledger DM access, and Delivery Memos view.
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

  @override
  void dispose() {
    // Free up memory by nullifying Uint8List variables
    if (_payload != null) {
      // Note: DmViewPayload is immutable, so we can't modify it directly
      // The payload will be garbage collected when dialog is disposed
      _payload = null;
    }
    super.dispose();
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
      final bytes = byteData.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: 'DM-${widget.dmNumber}.png', mimeType: 'image/png')],
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
    setState(() => _isGeneratingPdf = true);
    try {
      await widget.dmPrintService.printDeliveryMemo(widget.dmNumber);
      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(context, message: 'Print window opened');
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to open print window: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
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
              if (_isLoadingView) ...[
                const CircularProgressIndicator(color: AuthColors.info),
                const SizedBox(height: 20),
                Text(
                  'Loading DM-${widget.dmNumber}...',
                  style: const TextStyle(
                    color: AuthColors.textMain,
                    fontSize: 14,
                  ),
                ),
              ] else if (_hasError) ...[
                const Icon(Icons.error_outline, color: AuthColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load',
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: AspectRatio(
                        aspectRatio: 210 / 297,
                        child: DeliveryMemoDocument(
                          dmData: widget.dmData,
                          payload: _payload!,
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
            ],
          ),
        ),
      ),
    );
  }
}
