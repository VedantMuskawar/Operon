import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:flutter/material.dart';

/// Loads DM PDF and opens OperonPdfPreviewModal for preview, print, and save.
/// Shows loading state while generating PDF.
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
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateAndShowPreview();
  }

  Future<void> _generateAndShowPreview() async {
    try {
      final pdfBytes = await widget.dmPrintService.generatePdfBytes(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      await OperonPdfPreviewModal.show(
        context: context,
        pdfBytes: pdfBytes,
        title: 'DM-${widget.dmNumber}',
        pdfFileName: 'DM-${widget.dmNumber}.pdf',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
        DashSnackbar.show(
          context,
          message: 'Failed to generate DM PDF: $e',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AuthColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading) ...[
              const CircularProgressIndicator(color: AuthColors.info),
              const SizedBox(height: 20),
              Text(
                'Generating DM-${widget.dmNumber}...',
                style: const TextStyle(
                  color: AuthColors.textMain,
                  fontSize: 14,
                  fontFamily: 'SF Pro Display',
                ),
              ),
            ] else if (_hasError) ...[
              const Icon(Icons.error_outline, color: AuthColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Failed to generate PDF',
                style: const TextStyle(
                  color: AuthColors.textSub,
                  fontSize: 13,
                  fontFamily: 'SF Pro Display',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DashButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                variant: DashButtonVariant.outlined,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
