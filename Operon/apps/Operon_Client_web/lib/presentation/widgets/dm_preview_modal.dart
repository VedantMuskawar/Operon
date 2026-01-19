import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Modal dialog that shows DM preview and allows printing
/// Supports both HTML (universal template) and PDF (custom template)
class DmPreviewModal extends StatefulWidget {
  const DmPreviewModal({
    super.key,
    this.htmlString,
    this.pdfBytes,
  });

  final String? htmlString;
  final Uint8List? pdfBytes;

  @override
  State<DmPreviewModal> createState() => _DmPreviewModalState();

  /// Show the preview modal
  static Future<void> show({
    required BuildContext context,
    String? htmlString,
    Uint8List? pdfBytes,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => DmPreviewModal(
        htmlString: htmlString,
        pdfBytes: pdfBytes,
      ),
    );
  }
}

class _DmPreviewModalState extends State<DmPreviewModal> {
  late final String _iframeViewType;
  html.IFrameElement? _iframeElement;
  bool _isPrinting = false;
  int? _containerWidth;
  int? _containerHeight;

  @override
  void initState() {
    super.initState();
    // Create unique view type for iframe
    _iframeViewType = 'dm-preview-${DateTime.now().millisecondsSinceEpoch}';
    _registerIframeView();
  }

  void _registerIframeView() {
    // Register platform view for HTML iframe
    ui_web.platformViewRegistry.registerViewFactory(
      _iframeViewType,
      (int viewId) {
        _iframeElement = html.IFrameElement()
          ..id = 'iframe-$_iframeViewType'
          ..style.border = 'none';
        
        // Set content based on type (HTML or PDF)
        if (widget.pdfBytes != null) {
          // For PDF, create a data URL
          final base64Pdf = base64Encode(widget.pdfBytes!);
          _iframeElement!.src = 'data:application/pdf;base64,$base64Pdf';
        } else if (widget.htmlString != null) {
          // For HTML, use srcdoc
          _iframeElement!.srcdoc = widget.htmlString;
        }
        
        
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

  void _handlePrint() async {
    if (_iframeElement == null) return;

    setState(() {
      _isPrinting = true;
    });

    try {
      // Wait for iframe to be fully loaded
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Use JavaScript to directly access iframe's contentWindow and call print()
      // This prints the DM content inside the iframe, not the parent window
      // Find the iframe by searching for one with our DM content
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            // Find iframe by searching for one containing our DM content
            var allIframes = document.querySelectorAll('iframe');
            var targetIframe = null;
            
            for (var i = 0; i < allIframes.length; i++) {
              var frame = allIframes[i];
              // Check if this iframe has our DM content (HTML or PDF)
              if ((frame.srcdoc && frame.srcdoc.indexOf('DELIVERY MEMO') !== -1) ||
                  (frame.src && frame.src.indexOf('application/pdf') !== -1)) {
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
      print('Error printing iframe: $e');
    } finally {
      setState(() {
        _isPrinting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF11111B),
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B2C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header with title and buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF11111B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.preview, color: Colors.blue, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'DM Preview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isPrinting ? null : _handlePrint,
                    icon: _isPrinting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.print, color: Colors.white),
                    label: Text(
                      _isPrinting ? 'Printing...' : 'Print',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
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
