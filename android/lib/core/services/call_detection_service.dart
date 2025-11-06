import 'package:flutter/services.dart';
import 'dart:convert';
import 'call_order_lookup_service.dart';

class CallDetectionService {
  static CallDetectionService? _instance;
  static CallDetectionService get instance => _instance ??= CallDetectionService._();
  
  static const MethodChannel _channel = MethodChannel('com.example.operon/call_detection');
  static const MethodChannel _nativeOverlayChannel = MethodChannel('com.example.operon/native_overlay');
  
  final CallOrderLookupService _lookupService = CallOrderLookupService();
  
  Function(CallOrderInfo)? onIncomingCall;
  Function()? onCallOffhook;
  Function()? onCallEnded;

  CallDetectionService._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      print('CallDetectionService: Received method call: ${call.method}');
      switch (call.method) {
        case 'onIncomingCall':
          final phoneNumber = call.arguments['phoneNumber'] as String?;
          print('CallDetectionService: onIncomingCall - phoneNumber: $phoneNumber');
          if (phoneNumber != null) {
            // Look up pending orders
            try {
              print('CallDetectionService: Looking up orders for $phoneNumber');
              final orderInfo = await _lookupService.lookupPendingOrders(phoneNumber);
              print('CallDetectionService: Found ${orderInfo.orders.length} orders. Calling onIncomingCall callback');
              
              // Try to show native overlay first (appears above system UI)
              await _showNativeOverlay(orderInfo);
              
              // Also call Flutter callback for Flutter overlay (fallback)
              if (onIncomingCall != null) {
                onIncomingCall!(orderInfo);
                print('CallDetectionService: Callback executed successfully');
              } else {
                print('CallDetectionService: WARNING - onIncomingCall callback is null!');
              }
            } catch (e) {
              print('CallDetectionService: Error looking up orders: $e');
              // Still show overlay with empty orders
              final emptyOrderInfo = CallOrderInfo(
                phoneNumber: phoneNumber,
                orders: [],
              );
              await _showNativeOverlay(emptyOrderInfo);
              if (onIncomingCall != null) {
                onIncomingCall!(emptyOrderInfo);
              }
            }
          }
          break;
          
        case 'onCallOffhook':
          onCallOffhook?.call();
          break;
          
        case 'onCallEnded':
          onCallEnded?.call();
          await _hideNativeOverlay();
          break;
          
        default:
          break;
      }
    } catch (e) {
      print('Error handling method call ${call.method}: $e');
    }
  }

  /// Set the current organization ID for lookups
  Future<void> setOrganizationId(String organizationId) async {
    await _lookupService.setCurrentOrganizationId(organizationId);
  }
  
  /// Show native Android overlay
  Future<void> _showNativeOverlay(CallOrderInfo orderInfo) async {
    try {
      // Convert orders to JSON
      final ordersJson = jsonEncode(orderInfo.orders.map((order) => {
        'orderId': order.orderId,
        'placedDate': order.placedDate.toIso8601String(),
        'location': order.location,
        'trips': order.trips,
      }).toList());
      
      await _nativeOverlayChannel.invokeMethod('showOverlay', {
        'phoneNumber': orderInfo.phoneNumber,
        'clientName': orderInfo.clientName,
        'ordersJson': ordersJson,
      });
      print('CallDetectionService: Native overlay shown');
    } catch (e) {
      print('CallDetectionService: Error showing native overlay: $e');
    }
  }
  
  /// Hide native Android overlay
  Future<void> _hideNativeOverlay() async {
    try {
      await _nativeOverlayChannel.invokeMethod('hideOverlay');
      print('CallDetectionService: Native overlay hidden');
    } catch (e) {
      print('CallDetectionService: Error hiding native overlay: $e');
    }
  }
}
