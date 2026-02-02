import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:core_ui/theme/auth_colors.dart';

/// Shared PDF preview modal using the [printing] package's [PdfPreview].
/// Works on Web and Android; no dart:html or iframe.
class OperonPdfPreviewModal extends StatefulWidget {
  const OperonPdfPreviewModal({
    super.key,
    required this.pdfBytes,
    this.title = 'PDF Preview',
    this.pdfFileName,
  });

  final Uint8List pdfBytes;
  final String title;
  /// Filename when downloading/sharing (e.g. 'ledger.pdf'). Must include extension.
  final String? pdfFileName;

  @override
  State<OperonPdfPreviewModal> createState() => _OperonPdfPreviewModalState();

  /// Show the preview modal
  static Future<void> show({
    required BuildContext context,
    required Uint8List pdfBytes,
    String title = 'PDF Preview',
    String? pdfFileName,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => OperonPdfPreviewModal(
        pdfBytes: pdfBytes,
        title: title,
        pdfFileName: pdfFileName,
      ),
    );
  }
}

class _OperonPdfPreviewModalState extends State<OperonPdfPreviewModal> {
  bool _isPrinting = false;
  bool _isSharing = false;

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) => Future.value(widget.pdfBytes),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<void> _handleShareOrDownload() async {
    setState(() => _isSharing = true);
    try {
      final filename = widget.pdfFileName ?? 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(
        bytes: widget.pdfBytes,
        filename: filename,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share/download: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
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
          children: [
            // Header with title and buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AuthColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf,
                    color: AuthColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        color: AuthColors.textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isSharing ? null : _handleShareOrDownload,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                    label: Text(
                      _isSharing ? 'Downloading...' : 'Download',
                      style: const TextStyle(
                        color: AuthColors.primary,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AuthColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.print,
                            color: AuthColors.primary,
                            size: 20,
                          ),
                    label: Text(
                      _isPrinting ? 'Printing...' : 'Print',
                      style: const TextStyle(
                        color: AuthColors.primary,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AuthColors.textSub,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // PdfPreview (no built-in action bar)
            Expanded(
              child: PdfPreview(
                build: (PdfPageFormat format) => Future.value(widget.pdfBytes),
                useActions: false,
                canChangePageFormat: false,
                canChangeOrientation: false,
                canDebug: false,
                pdfFileName: widget.pdfFileName ?? 'preview.pdf',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
