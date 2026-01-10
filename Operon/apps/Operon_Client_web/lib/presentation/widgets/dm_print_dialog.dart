import 'dart:typed_data';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:flutter/material.dart';

/// Dialog for automatically generating and printing DM PDF
/// Uses print preferences from DM Settings
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
  bool _isGenerating = true;
  bool _hasError = false;
  String? _errorMessage;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    // Auto-generate PDF when dialog opens
    _generatePdf();
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isGenerating = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final pdfBytes = await widget.dmPrintService.generatePdfBytes(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );

      if (mounted) {
        setState(() {
          _pdfBytes = pdfBytes;
          _isGenerating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientName = widget.dmData['clientName'] as String? ?? 'N/A';
    final scheduledDate = widget.dmData['scheduledDate'];
    String dateText = 'N/A';
    if (scheduledDate != null) {
      try {
        if (scheduledDate is Map && scheduledDate.containsKey('_seconds')) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            (scheduledDate['_seconds'] as int) * 1000,
          );
          dateText = '${date.day}/${date.month}/${date.year}';
        } else if (scheduledDate is DateTime) {
          dateText = '${scheduledDate.day}/${scheduledDate.month}/${scheduledDate.year}';
        }
      } catch (e) {
        dateText = 'N/A';
      }
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF11111B),
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            'DM-${widget.dmNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // DM Info Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          clientName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Date: $dateText',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isGenerating) ...[
              const Center(
                child: CircularProgressIndicator(),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Generating PDF...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ] else if (_hasError) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage ?? 'Failed to generate PDF',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DashButton(
                label: 'Retry',
                onPressed: _generatePdf,
                icon: Icons.refresh,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PDF generated successfully',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (!_isGenerating && !_hasError && _pdfBytes != null) ...[
          DashButton(
            label: 'Print',
            onPressed: _handlePrint,
            icon: Icons.print,
          ),
          DashButton(
            label: 'Save PDF',
            onPressed: _handleSavePdf,
            icon: Icons.download,
          ),
        ],
      ],
    );
  }

  Future<void> _handlePrint() async {
    if (_pdfBytes == null) return;

    try {
      await widget.dmPrintService.printPdfBytes(
        pdfBytes: _pdfBytes!,
      );

      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: 'Print dialog opened successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to print: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _handleSavePdf() async {
    if (_pdfBytes == null) return;

    try {
      await widget.dmPrintService.savePdfBytes(
        pdfBytes: _pdfBytes!,
        fileName: 'DM-${widget.dmNumber}.pdf',
      );

      if (mounted) {
        Navigator.of(context).pop();
        DashSnackbar.show(
          context,
          message: 'PDF saved successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        DashSnackbar.show(
          context,
          message: 'Failed to save PDF: ${e.toString()}',
          isError: true,
        );
      }
    }
  }
}
