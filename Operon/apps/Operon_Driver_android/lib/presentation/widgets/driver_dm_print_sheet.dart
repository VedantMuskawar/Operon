import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:operon_driver_android/core/services/dm_print_helper.dart';

/// Bottom sheet for printing or sharing DM PDF in the Driver app.
void showDriverDmPrintSheet({
  required BuildContext context,
  required String organizationId,
  required Map<String, dynamic> dmData,
  required int dmNumber,
  required DmPrintHelper dmPrintHelper,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1B1B2C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  'DM-$dmNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              dmData['clientName'] as String? ?? 'N/A',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _DriverDmPrintActions(
              organizationId: organizationId,
              dmData: dmData,
              dmNumber: dmNumber,
              dmPrintHelper: dmPrintHelper,
              onDone: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DriverDmPrintActions extends StatefulWidget {
  const _DriverDmPrintActions({
    required this.organizationId,
    required this.dmData,
    required this.dmNumber,
    required this.dmPrintHelper,
    required this.onDone,
  });

  final String organizationId;
  final Map<String, dynamic> dmData;
  final int dmNumber;
  final DmPrintHelper dmPrintHelper;
  final VoidCallback onDone;

  @override
  State<_DriverDmPrintActions> createState() => _DriverDmPrintActionsState();
}

class _DriverDmPrintActionsState extends State<_DriverDmPrintActions> {
  bool _isPrinting = false;
  bool _isSharing = false;
  String? _error;

  Future<void> _print() async {
    setState(() {
      _isPrinting = true;
      _error = null;
    });
    try {
      final pdfBytes = await widget.dmPrintHelper.generatePdfBytes(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );
      await widget.dmPrintHelper.printPdfBytes(pdfBytes);
      if (mounted) {
        setState(() => _isPrinting = false);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Print dialog opened')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPrinting = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print: $e'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  Future<void> _share() async {
    setState(() {
      _isSharing = true;
      _error = null;
    });
    try {
      final pdfBytes = await widget.dmPrintHelper.generatePdfBytes(
        organizationId: widget.organizationId,
        dmData: widget.dmData,
      );
      await widget.dmPrintHelper.sharePdfBytes(
        pdfBytes: pdfBytes,
        fileName: 'DM-${widget.dmNumber}.pdf',
      );
      if (mounted) {
        setState(() => _isSharing = false);
        widget.onDone();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF shared')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: AuthColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isPrinting || _isSharing ? null : _print,
                icon: _isPrinting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined, size: 20),
                label: Text(_isPrinting ? 'Printing…' : 'Print'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _isPrinting || _isSharing ? null : _share,
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share_outlined, size: 20),
                label: Text(_isSharing ? 'Sharing…' : 'Share PDF'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
