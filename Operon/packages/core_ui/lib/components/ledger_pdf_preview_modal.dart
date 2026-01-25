import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:core_ui/core_ui.dart' show AuthColors;

/// Modal dialog that shows ledger PDF preview and allows printing/downloading
class LedgerPdfPreviewModal extends StatefulWidget {
  const LedgerPdfPreviewModal({
    super.key,
    required this.pdfBytes,
    this.title = 'Ledger Preview',
  });

  final Uint8List pdfBytes;
  final String title;

  @override
  State<LedgerPdfPreviewModal> createState() => _LedgerPdfPreviewModalState();

  /// Show the preview modal
  static Future<void> show({
    required BuildContext context,
    required Uint8List pdfBytes,
    String title = 'Ledger Preview',
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => LedgerPdfPreviewModal(
        pdfBytes: pdfBytes,
        title: title,
      ),
    );
  }
}

class _LedgerPdfPreviewModalState extends State<LedgerPdfPreviewModal> {
  late final String _iframeViewType;
  html.IFrameElement? _iframeElement;
  bool _isPrinting = false;
  bool _isDownloading = false;
  int? _containerWidth;
  int? _containerHeight;

  @override
  void initState() {
    super.initState();
    // Create unique view type for iframe
    _iframeViewType = 'ledger-pdf-preview-${DateTime.now().millisecondsSinceEpoch}';
    _registerIframeView();
  }

  void _registerIframeView() {
    // Register platform view for PDF iframe
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeViewType,
      (int viewId) {
        _iframeElement = html.IFrameElement()
          ..id = 'iframe-$_iframeViewType'
          ..style.border = 'none';
        
        // For PDF, create a data URL
        final base64Pdf = base64Encode(widget.pdfBytes);
        _iframeElement!.src = 'data:application/pdf;base64,$base64Pdf';
        
        // Set explicit width and height to fix Platform View warning
        // Update dimensions when container size is known
        if (_containerWidth != null && _containerHeight != null) {
          _iframeElement!.style.width = '${_containerWidth}px';
          _iframeElement!.style.height = '${_containerHeight}px';
        } else {
          // Set default dimensions (will be updated in build)
          _iframeElement!.style.width = '100%';
          _iframeElement!.style.height = '100%';
        }
        
        // Update dimensions once iframe loads
        _iframeElement!.onLoad.listen((_) {
          if (_containerWidth != null && _containerHeight != null && mounted) {
            _iframeElement!.style.width = '${_containerWidth}px';
            _iframeElement!.style.height = '${_containerHeight}px';
          }
        });
        
        return _iframeElement!;
      },
    );
  }

  Future<void> _handlePrint() async {
    if (_iframeElement == null) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      // Wait for iframe to be fully loaded
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Use JavaScript to directly access iframe's contentWindow and call print()
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            // Find iframe by searching for one containing PDF
            var allIframes = document.querySelectorAll('iframe');
            var targetIframe = null;
            
            for (var i = 0; i < allIframes.length; i++) {
              var frame = allIframes[i];
              // Check if this iframe has PDF content
              if (frame.src && frame.src.indexOf('application/pdf') !== -1) {
                targetIframe = frame;
                break;
              }
            }
            
            // If found, print its content
            if (targetIframe && targetIframe.contentWindow) {
              targetIframe.contentWindow.focus();
              targetIframe.contentWindow.print();
              return true;
            }
            return false;
          } catch (e) {
            console.error('Print error:', e);
            return false;
          }
        })();
        '''
      ]);
    } catch (e) {
      // If iframe print fails, log error
      print('Error printing PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Create a blob URL for download
      final blob = html.Blob([widget.pdfBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'ledger_${DateTime.now().millisecondsSinceEpoch}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
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
                  // Download button
                  TextButton.icon(
                    onPressed: _isDownloading ? null : _handleDownload,
                    icon: _isDownloading
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
                      _isDownloading ? 'Downloading...' : 'Download',
                      style: const TextStyle(
                        color: AuthColors.primary,
                        fontFamily: 'SF Pro Display',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Print button
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
                  // Close button
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
            // Preview content
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Store container dimensions for iframe
                  final width = constraints.maxWidth.isFinite 
                      ? constraints.maxWidth.toInt() 
                      : 800;
                  final height = constraints.maxHeight.isFinite 
                      ? constraints.maxHeight.toInt() 
                      : 600;
                  
                  // Update stored dimensions
                  _containerWidth = width;
                  _containerHeight = height;
                  
                  // Update iframe dimensions if element exists
                  if (_iframeElement != null) {
                    _iframeElement!.style.width = '${width}px';
                    _iframeElement!.style.height = '${height}px';
                  }
                  
                  return Container(
                    color: Colors.white,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: HtmlElementView(viewType: _iframeViewType),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
