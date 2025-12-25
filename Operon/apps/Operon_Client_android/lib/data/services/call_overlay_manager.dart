import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class CallOverlayManager {
  static const MethodChannel _channel = MethodChannel('call_overlay');

  void _debugLog(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[CallOverlayManager] $message');
      if (error != null) {
        debugPrint('[CallOverlayManager] Error: $error');
      }
    }
  }

  /// Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final status = await Permission.systemAlertWindow.status;
      _debugLog('Overlay permission status: $status');
      return status.isGranted;
    } catch (e) {
      _debugLog('Error checking overlay permission', e);
      return false;
    }
  }

  /// Request overlay permission
  Future<bool> requestOverlayPermission() async {
    try {
      _debugLog('Requesting overlay permission...');
      final status = await Permission.systemAlertWindow.request();
      _debugLog('Overlay permission request result: $status');
      return status.isGranted;
    } catch (e) {
      _debugLog('Error requesting overlay permission', e);
      return false;
    }
  }

  /// Show overlay with caller data
  Future<bool> showOverlay({
    required String clientId,
    required String clientName,
    required String clientPhone,
    required List<Map<String, dynamic>> pendingOrders,
    required List<Map<String, dynamic>> completedOrders,
  }) async {
    try {
      _debugLog('Attempting to show overlay');
      _debugLog('Client: $clientName ($clientPhone)');
      _debugLog('Pending orders: ${pendingOrders.length}');
      _debugLog('Completed orders: ${completedOrders.length}');

      final hasPermission = await hasOverlayPermission();
      _debugLog('Has overlay permission: $hasPermission');

      if (!hasPermission) {
        _debugLog('Requesting overlay permission...');
        final granted = await requestOverlayPermission();
        _debugLog('Permission granted: $granted');
        if (!granted) {
          _debugLog('Overlay permission denied. Cannot show overlay.');
          return false;
        }
      }

      _debugLog('Invoking native showOverlay method...');
      final result = await _channel.invokeMethod<bool>(
        'showOverlay',
        {
          'clientId': clientId,
          'clientName': clientName,
          'clientPhone': clientPhone,
          'pendingOrders': pendingOrders,
          'completedOrders': completedOrders,
        },
      );

      _debugLog('Native showOverlay result: $result');
      return result ?? false;
    } catch (e, stackTrace) {
      _debugLog('Error showing overlay', e);
      if (kDebugMode) {
        debugPrint('[CallOverlayManager] Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Hide overlay
  Future<bool> hideOverlay() async {
    try {
      _debugLog('Attempting to hide overlay');
      final result = await _channel.invokeMethod<bool>('hideOverlay');
      _debugLog('Native hideOverlay result: $result');
      return result ?? false;
    } catch (e) {
      _debugLog('Error hiding overlay', e);
      return false;
    }
  }

  /// Check if overlay is currently visible
  Future<bool> isOverlayVisible() async {
    try {
      final result = await _channel.invokeMethod<bool>('isOverlayVisible');
      _debugLog('Is overlay visible: $result');
      return result ?? false;
    } catch (e) {
      _debugLog('Error checking overlay visibility', e);
      return false;
    }
  }

  /// Test overlay (for debugging)
  Future<bool> testOverlay() async {
    _debugLog('Testing overlay with sample data...');
    return showOverlay(
      clientId: 'test_client',
      clientName: 'Test Client',
      clientPhone: '+919876543210',
      pendingOrders: [
        {
          'id': 'test_order_1',
          'productName': 'Test Product',
          'fixedQuantityPerTrip': 100,
          'estimatedTrips': 2,
        }
      ],
      completedOrders: [
        {
          'id': 'test_transaction_1',
          'type': 'advance_on_order',
          'amount': 5000,
          'transactionDate': DateTime.now().toIso8601String(),
        }
      ],
    );
  }
}

