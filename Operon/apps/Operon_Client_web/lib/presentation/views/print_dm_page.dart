import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_datasources/core_datasources.dart';
import 'package:core_ui/core_ui.dart';
import 'package:dash_web/data/datasources/payment_accounts_data_source.dart';
import 'package:dash_web/data/repositories/dm_settings_repository.dart';
import 'package:dash_web/data/repositories/payment_accounts_repository.dart';
import 'package:dash_web/data/services/dm_print_service.dart';
import 'package:dash_web/data/services/qr_code_service.dart';
import 'package:flutter/material.dart';

/// Print page for Delivery Memos that opens in a new window and triggers browser print.
/// Route: /print-dm/:dmNumber (matches PaveBoard's exact flow)
class PrintDMPage extends StatefulWidget {
  const PrintDMPage({super.key});

  @override
  State<PrintDMPage> createState() => _PrintDMPageState();
}

class _PrintDMPageState extends State<PrintDMPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndRenderDM();
  }

  Future<void> _loadAndRenderDM() async {
    try {
      // Get dmNumber from URL pathname (ignores hash fragment)
      final pathname = html.window.location.pathname ?? '';
      
      // Extract dmNumber from pathname (e.g., /print-dm/5004)
      final pathSegments = pathname.split('/').where((s) => s.isNotEmpty).toList();
      final dmNumberIndex = pathSegments.indexOf('print-dm');
      
      if (dmNumberIndex == -1 || dmNumberIndex >= pathSegments.length - 1) {
        print('[PrintDMPage] ERROR: Could not find print-dm in path segments: $pathSegments');
        setState(() {
          _hasError = true;
          _errorMessage = 'DM number is required';
          _isLoading = false;
        });
        return;
      }

      final dmNumberParam = pathSegments[dmNumberIndex + 1];
      final dmNumber = int.tryParse(dmNumberParam);
      
      if (dmNumber == null) {
        print('[PrintDMPage] ERROR: Invalid DM number format: $dmNumberParam');
        setState(() {
          _hasError = true;
          _errorMessage = 'Invalid DM number';
          _isLoading = false;
        });
        return;
      }
      
      print('[PrintDMPage] Parsed DM number: $dmNumber');

      // Create DmPrintService instance
      final dmSettingsRepo = DmSettingsRepository(
        dataSource: DmSettingsDataSource(),
      );
      final paymentAccountsRepo = PaymentAccountsRepository(
        dataSource: PaymentAccountsDataSource(),
      );
      final qrCodeService = QrCodeService();
      
      final printService = DmPrintService(
        dmSettingsRepository: dmSettingsRepo,
        paymentAccountsRepository: paymentAccountsRepo,
        qrCodeService: qrCodeService,
      );

      // FIRST: Check sessionStorage for cached data (instant print flow)
      print('[PrintDMPage] Checking sessionStorage for cached print data...');
      final cachedData = printService.getPrintDataFromSession(dmNumber);
      
      if (cachedData != null) {
        print('[PrintDMPage] Found cached data in sessionStorage - using instant print flow');
        
        // Use cached HTML string immediately
        final htmlString = cachedData.htmlString;
        
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });
        
        print('[PrintDMPage] Replacing document and triggering print immediately...');
        
        // Inject HTML and trigger print immediately (no delay needed - data is ready)
        Future.delayed(const Duration(milliseconds: 300), () {
          _replaceDocumentAndPrint(htmlString);
        });
        
        return;
      }
      
      // FALLBACK: Fetch from Firestore (for direct URL access or if sessionStorage failed)
      print('[PrintDMPage] No cached data found - fetching from Firestore...');
      
      // Fetch DM data by dmNumber
      final dmData = await printService.fetchDmByNumberOrId(
        organizationId: null,
        dmNumber: dmNumber,
        dmId: null,
        tripData: null,
      );

      if (dmData == null) {
        print('[PrintDMPage] ERROR: DM not found for number: $dmNumber');
        setState(() {
          _hasError = true;
          _errorMessage = 'DM not found';
          _isLoading = false;
        });
        return;
      }

      // Extract organizationId from DM data
      final orgId = dmData['organizationId'] as String? ?? 
                    dmData['orgID'] as String?;
      
      if (orgId == null || orgId.isEmpty) {
        print('[PrintDMPage] ERROR: Organization ID not found in DM data');
        setState(() {
          _hasError = true;
          _errorMessage = 'Organization ID not found in DM data';
          _isLoading = false;
        });
        return;
      }

      // Fetch related order data
      final orderId = dmData['orderID'] as String?;
      if (orderId != null && orderId.isNotEmpty) {
        final orderData = await _fetchRelatedOrder(orderId, orgId);
        if (orderData != null) {
          dmData['clientPhone'] = orderData['clientPhoneNumber'] as String? ?? 
                                  dmData['clientPhone'] as String?;
          dmData['driverName'] = orderData['driverName'] as String? ?? 
                                 dmData['driverName'] as String?;
          dmData['driverPhone'] = orderData['driverPhone'] as String? ?? 
                                  dmData['driverPhone'] as String?;
        }
      }

      // Load DM view data
      final payload = await printService.loadDmViewData(
        organizationId: orgId,
        dmData: dmData,
      );

      // Generate HTML
      final htmlString = printService.generateDmHtmlForPrint(
        dmData: dmData,
        dmSettings: payload.dmSettings,
        paymentAccount: payload.paymentAccount,
        logoBytes: payload.logoBytes,
        qrCodeBytes: payload.qrCodeBytes,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      print('[PrintDMPage] Replacing document and triggering print...');

      // Inject HTML and trigger print
      Future.delayed(const Duration(milliseconds: 600), () {
        _replaceDocumentAndPrint(htmlString);
      });
    } catch (e, stackTrace) {
      print('[PrintDMPage] ERROR in _loadAndRenderDM: $e');
      print('[PrintDMPage] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Fetch related order data from SCH_ORDERS collection (like PaveBoard does)
  Future<Map<String, dynamic>?> _fetchRelatedOrder(String orderId, String orgId) async {
    try {
      print('[PrintDMPage] Querying SCH_ORDERS for orderID: $orderId, orgID: $orgId');
      final orderQuery = FirebaseFirestore.instance
          .collection('SCH_ORDERS')
          .where('orderID', isEqualTo: orderId)
          .where('orgID', isEqualTo: orgId)
          .limit(1);
      
      final orderSnap = await orderQuery.get();
      print('[PrintDMPage] Order query returned ${orderSnap.docs.length} documents');
      
      if (orderSnap.docs.isNotEmpty) {
        final orderData = orderSnap.docs.first.data();
        print('[PrintDMPage] Order data found, converting timestamps...');
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
        print('[PrintDMPage] Order data converted successfully');
        return convertedData;
      }
      print('[PrintDMPage] No order data found');
      return null;
    } catch (e, stackTrace) {
      print('[PrintDMPage] ERROR fetching related order: $e');
      print('[PrintDMPage] Stack trace: $stackTrace');
      // Silently fail - order data is optional
      return null;
    }
  }

  /// Replace entire document with HTML content (matches PaveBoard's approach)
  void _replaceDocumentAndPrint(String htmlString) {
    try {
      print('[PrintDMPage] Replacing document with HTML...');
      
      // Use JavaScript interop to replace entire document (like PaveBoard)
      // This completely replaces the Flutter app with the HTML content
      // Create a JavaScript function to handle document replacement safely
      final jsCode = '''
        (function() {
          document.open();
          document.write(${_escapeJsString(htmlString)});
          document.close();
        })();
      ''';
      
      print('[PrintDMPage] Executing JavaScript to replace document...');
      js.context.callMethod('eval', [jsCode]);
      
      print('[PrintDMPage] Document replaced, will trigger print in 300ms...');
      
      // Trigger print dialog after content is rendered
      Future.delayed(const Duration(milliseconds: 300), () {
        print('[PrintDMPage] Triggering window.print()...');
        html.window.print();
        print('[PrintDMPage] Print dialog triggered');
      });
    } catch (e, stackTrace) {
      print('[PrintDMPage] ERROR replacing document: $e');
      print('[PrintDMPage] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to render print preview: $e';
        });
      }
    }
  }

  /// Escape a string for safe use in JavaScript
  String _escapeJsString(String str) {
    // Use JSON encoding to properly escape all special characters
    return jsonEncode(str);
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Match PaveBoard's loading UI style
      return Scaffold(
        backgroundColor: const Color(0xFF141416),
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withOpacity(0.75),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    fontWeight: FontWeight.w700,
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
    }

    if (_hasError) {
      return Scaffold(
        backgroundColor: AuthColors.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AuthColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Failed to load DM',
                  style: TextStyle(
                    color: AuthColors.textSub,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                DashButton(
                  label: 'Close',
                  onPressed: () {
                    if (html.window.opener != null) {
                      html.window.close();
                    } else {
                      html.window.history.back();
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
}
