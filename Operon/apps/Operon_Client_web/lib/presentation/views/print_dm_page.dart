import 'dart:html' as html;
import 'dart:convert';
import 'package:dash_web/data/services/js_util_bridge.dart' as js_util;
import 'package:core_ui/core_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:js/js.dart';

/// Print page for Delivery Memos that opens in a new window and triggers browser print.
/// Route: /print-dm/:dmNumber (matches PaveBoard's exact flow)
class PrintDMPage extends StatefulWidget {
  const PrintDMPage({super.key});

  @override
  State<PrintDMPage> createState() => _PrintDMPageState();
}

@JS('myJsFunction')
external void myJsFunction(String arg1, String arg2);

class _PrintDMPageState extends State<PrintDMPage> {
  @override
  void initState() {
    super.initState();
    _startPrintFlow();
  }

  Future<void> _startPrintFlow() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    final flowStopwatch = Stopwatch()..start();

    try {
      // Extract DM number from route
      final uri = Uri.base;
      final dmNumberRaw =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null;
      if (dmNumberRaw == null || dmNumberRaw.isEmpty) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Invalid or missing DM number in URL.';
        });
        return;
      }

      final dmNumber =
          int.tryParse(dmNumberRaw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (dmNumber == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Invalid DM number format in URL.';
        });
        return;
      }

      // 1. Try to load from sessionStorage (unified print flow) - FASTEST PATH
      try {
        final storageKey = 'temp_print_data_$dmNumber';
        final cachedJson = html.window.sessionStorage[storageKey];
        if (cachedJson != null && cachedJson.isNotEmpty) {
          final cachedData = jsonDecode(cachedJson) as Map<String, dynamic>;
          final htmlString = cachedData['htmlString'] as String?;
          if (htmlString != null) {
            html.window.sessionStorage.remove(storageKey);
            debugPrint(
                '[PrintDMPage] Using cached print data (${flowStopwatch.elapsedMilliseconds}ms)');
            _replaceDocumentAndPrint(htmlString);
            return;
          }
        }
      } catch (e) {
        debugPrint('[PrintDMPage] sessionStorage failed: $e');
      }

      debugPrint('[PrintDMPage] Cache miss, fetching from Firestore...');
      final firestoreStopwatch = Stopwatch()..start();

      // 2. Fallback: Fetch DM data from Firestore
      final dmSnap = await FirebaseFirestore.instance
          .collection('DELIVERY_MEMOS')
          .where('dmNumber', isEqualTo: dmNumber)
          .limit(1)
          .get();

      if (!mounted) return;
      if (dmSnap.docs.isEmpty) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage = 'Delivery Memo not found.';
        });
        return;
      }

      final dmData = dmSnap.docs.first.data();
      firestoreStopwatch.stop();
      debugPrint(
          '[PrintDMPage] DM query completed (${firestoreStopwatch.elapsedMilliseconds}ms)');

      final orderId = dmData['orderID'] as String?;
      final orgId = dmData['orgID'] as String?;

      // Check which data is missing and needs to be fetched from order
      final hasClientPhone = _hasNonEmptyString(
        dmData,
        ['clientPhone', 'clientPhoneNumber', 'customerNumber'],
      );
      final hasDriverName = _hasNonEmptyString(dmData, ['driverName']);
      final hasDriverPhone =
          _hasNonEmptyString(dmData, ['driverPhone', 'driverPhoneNumber']);

      Map<String, dynamic>? orderData;

      // Only fetch order if it has the data we need
      if (orderId != null &&
          orgId != null &&
          (!hasClientPhone || !hasDriverName || !hasDriverPhone)) {
        final orderStopwatch = Stopwatch()..start();
        orderData = await _fetchRelatedOrder(orderId, orgId);
        orderStopwatch.stop();
        debugPrint(
            '[PrintDMPage] Order query completed (${orderStopwatch.elapsedMilliseconds}ms)');
      }

      // Generate HTML
      final htmlString = _generateHtml(dmData, orderData);
      flowStopwatch.stop();
      debugPrint(
          '[PrintDMPage] Total flow time: ${flowStopwatch.elapsedMilliseconds}ms');

      _replaceDocumentAndPrint(htmlString);
    } catch (e) {
      flowStopwatch.stop();
      debugPrint(
          '[PrintDMPage] Flow failed after ${flowStopwatch.elapsedMilliseconds}ms: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Error loading Delivery Memo: $e';
      });
    }
  }

  String _generateHtml(
      Map<String, dynamic> dmData, Map<String, dynamic>? orderData) {
    // TODO: Replace with real HTML template. This is a placeholder.
    final dmNumber = dmData['dmNumber'] ?? '';
    final clientName = orderData != null ? (orderData['clientName'] ?? '') : '';
    final date = dmData['date']?.toString() ?? '';
    return '''
        <html>
          <head>
            <title>Delivery Memo $dmNumber</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 40px; }
              h1 { color: #0A84FF; }
              .meta { margin-bottom: 24px; }
            </style>
          </head>
          <body>
            <h1>Delivery Memo #$dmNumber</h1>
            <div class="meta">
              <strong>Date:</strong> $date<br>
              <strong>Client:</strong> $clientName
            </div>
            <p>Replace this with the full DM details and table as needed.</p>
          </body>
        </html>
      ''';
  }

  // Example JS interop usage
  void callJsFunction() {
    myJsFunction('arg1', 'arg2');
  }

  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF141416),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withOpacity(0.75),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0A84FF), Color(0xFF0066CC)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A84FF).withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🚚',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Loading Delivery Memo',
                  style: TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    letterSpacing: -0.02,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Preparing Document...',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Color(0xFF0A84FF),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_hasError) {
      return Scaffold(
        backgroundColor: AuthColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(
                  Icons.error_outline,
                  color: AuthColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load DM',
                  style: const TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                DashButton(
                  label: 'Close',
                  onPressed: () {
                    if (web.window.opener != null) {
                      web.window.close();
                    } else {
                      web.window.history.back();
                    }
                  },
                  variant: DashButtonVariant.outlined,
                ),
              ],
            ),
          ),
        ),
      );
    }
    // This should not be reached as HTML replacement happens before this
    // But keep as fallback
    return const SizedBox.shrink();
  }

  /// Fetch related order data from SCH_ORDERS collection (like PaveBoard does)
  Future<Map<String, dynamic>?> _fetchRelatedOrder(
      String orderId, String orgId) async {
    try {
      debugPrint(
          '[PrintDMPage] Querying SCH_ORDERS for orderID: $orderId, orgID: $orgId');
      final orderQuery = FirebaseFirestore.instance
          .collection('SCH_ORDERS')
          .where('orderID', isEqualTo: orderId)
          .where('orgID', isEqualTo: orgId)
          .limit(1);

      final orderSnap = await orderQuery.get();
      if (!context.mounted) return null;
      debugPrint(
          '[PrintDMPage] Order query returned ${orderSnap.docs.length} documents');
      if (orderSnap.docs.isNotEmpty) {
        final orderData = orderSnap.docs.first.data();
        debugPrint('[PrintDMPage] Order data found, converting timestamps...');
        // Convert Firestore Timestamp to Map format
        final convertedData = <String, dynamic>{};
        orderData.forEach((key, value) {
          if (value is Timestamp) {
            convertedData[key] = {
              '_seconds': value.seconds,
              '_nanoseconds': value.nanoseconds,
            };
          } else {
            convertedData[key] = value;
          }
        });
        debugPrint('[PrintDMPage] Order data converted successfully');
        return convertedData;
      }
      debugPrint('[PrintDMPage] No order data found');
      return null;
    } catch (e, stackTrace) {
      debugPrint('[PrintDMPage] ERROR fetching related order: $e');
      debugPrint('[PrintDMPage] Stack trace: $stackTrace');
      // Silently fail - order data is optional
      return null;
    }
  }

  /// Replace entire document with HTML content (matches PaveBoard's approach)
  void _replaceDocumentAndPrint(String htmlString) {
    try {
      debugPrint('[PrintDMPage] Replacing document with HTML...');
      final stopwatch = Stopwatch()..start();

      final doc = html.window.document;

      try {
        js_util.callMethod(doc, 'open', const []);
        js_util.callMethod(doc, 'write', [htmlString]);
        js_util.callMethod(doc, 'close', const []);
      } catch (_) {
        final documentElement = doc.documentElement;
        if (documentElement != null) {
          documentElement.innerHtml = htmlString;
        }
      }

      stopwatch.stop();
      debugPrint(
          '[PrintDMPage] Document replaced in ${stopwatch.elapsedMilliseconds}ms');

      _waitForDomReadyAndPrint();
    } catch (e) {
      debugPrint('[PrintDMPage] Error replacing document: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to print document: $e';
      });
    }
  }

  bool _hasNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<void> _waitForDomReadyAndPrint() async {
    try {
      const maxWaitMs = 4000;
      const pollMs = 100;
      var waitedMs = 0;

      while (waitedMs < maxWaitMs) {
        final readyState = html.window.document.readyState;
        final images = html.window.document.querySelectorAll('img');
        final allImagesLoaded = images.every((img) {
          if (img is html.ImageElement) {
            return (img.complete ?? false) && img.naturalWidth > 0;
          }
          return true;
        });

        if (readyState == 'complete' && allImagesLoaded) {
          break;
        }

        await Future.delayed(const Duration(milliseconds: pollMs));
        waitedMs += pollMs;
      }

      html.window.requestAnimationFrame((_) {
        html.window.print();
      });
    } catch (e) {
      debugPrint('[PrintDMPage] Print wait failed, printing anyway: $e');
      html.window.print();
    }
  }
}
