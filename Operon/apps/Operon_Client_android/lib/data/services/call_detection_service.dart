import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CallDetectionService {
  static const MethodChannel _channel = MethodChannel('call_detection');
  StreamController<String>? _incomingCallController;
  StreamController<String>? _callEndController;

  void _debugLog(String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[CallDetectionService] $message');
      if (error != null) {
        debugPrint('[CallDetectionService] Error: $error');
      }
    }
  }

  /// Stream of incoming call phone numbers
  Stream<String> get incomingCalls {
    _incomingCallController ??= StreamController<String>.broadcast();
    return _incomingCallController!.stream;
  }

  /// Stream of call end events
  Stream<String> get callEnds {
    _callEndController ??= StreamController<String>.broadcast();
    return _callEndController!.stream;
  }

  /// Start listening for incoming calls
  Future<bool> startListening() async {
    try {
      _debugLog('Starting call detection...');
      
      // Set up method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      _debugLog('Method call handler set up');

      // Start listening on native side
      _debugLog('Invoking native startListening...');
      final result = await _channel.invokeMethod<bool>('startListening');
      _debugLog('Native startListening result: $result');
      return result ?? false;
    } catch (e, stackTrace) {
      _debugLog('Error starting call detection', e);
      if (kDebugMode) {
        debugPrint('[CallDetectionService] Stack trace: $stackTrace');
      }
      return false;
    }
  }

  /// Stop listening for calls
  Future<void> stopListening() async {
    try {
      _debugLog('Stopping call detection...');
      await _channel.invokeMethod('stopListening');
      _debugLog('Call detection stopped');
    } catch (e) {
      _debugLog('Error stopping call detection', e);
    }
  }

  /// Handle method calls from native side
  Future<void> _handleMethodCall(MethodCall call) async {
    _debugLog('Method call received: ${call.method}');
    switch (call.method) {
      case 'onIncomingCall':
        final phoneNumber = call.arguments as String?;
        _debugLog('Incoming call from: $phoneNumber');
        if (phoneNumber != null) {
          _incomingCallController?.add(phoneNumber);
          _debugLog('Phone number added to stream');
        } else {
          _debugLog('Warning: Phone number is null');
        }
        break;
      case 'onCallEnd':
        _debugLog('Call ended');
        _callEndController?.add('');
        break;
      default:
        _debugLog('Unknown method: ${call.method}');
    }
  }

  /// Dispose resources
  void dispose() {
    _debugLog('Disposing call detection service');
    stopListening();
    _incomingCallController?.close();
    _incomingCallController = null;
    _callEndController?.close();
    _callEndController = null;
  }
}

