import 'dart:developer' as developer;
import 'dart:io';

import 'package:dash_mobile/data/utils/caller_overlay_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _log(String msg) {
  developer.log(msg, name: 'CallerOverlay');
}

const _channel = MethodChannel('operon.app/caller_overlay');
const _keyCallerIdEnabled = 'caller_id_enabled';
const _overlayPhoneFile = 'caller_overlay_phone.txt';

/// Service to trigger overlay on incoming call, manage permissions, and close overlay.
class CallerOverlayService {
  CallerOverlayService._();
  static final CallerOverlayService instance = CallerOverlayService._();

  /// Check if overlay permission is granted.
  Future<bool> isOverlayPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    return FlutterOverlayWindow.isPermissionGranted();
  }

  /// Request overlay permission (opens system overlay settings).
  Future<bool?> requestOverlayPermission() async {
    if (!Platform.isAndroid) return null;
    return FlutterOverlayWindow.requestPermission();
  }

  /// Check if phone state permission is granted.
  Future<bool> isPhonePermissionGranted() async {
    if (!Platform.isAndroid) return true;
    final s = await Permission.phone.status;
    return s.isGranted;
  }

  /// Request phone state permission.
  Future<bool> requestPhonePermission() async {
    if (!Platform.isAndroid) return true;
    final s = await Permission.phone.request();
    return s.isGranted;
  }

  /// Check if Caller ID overlay can run (overlay + phone permissions).
  Future<bool> canRunCallerOverlay() async {
    if (!Platform.isAndroid) return false;
    final overlay = await isOverlayPermissionGranted();
    final phone = await isPhonePermissionGranted();
    return overlay && phone;
  }

  /// Get pending incoming phone from native (when app launched by CallDetectionReceiver).
  /// Returns phone string or null, and clears pending state.
  Future<String?> getPendingIncomingCall() async {
    if (!Platform.isAndroid) return null;
    try {
      final phone =
          await _channel.invokeMethod<String>('getPendingIncomingCall');
      return (phone != null && phone.isNotEmpty) ? phone : null;
    } on PlatformException catch (e) {
      _log('getPendingIncomingCall error: $e');
      return null;
    }
  }

  /// Peek pending incoming phone without clearing. Use [clearPendingIncomingCall] after successful trigger.
  Future<String?> getPendingIncomingCallPeek() async {
    if (!Platform.isAndroid) return null;
    try {
      final phone =
          await _channel.invokeMethod<String>('getPendingIncomingCallPeek');
      return (phone != null && phone.isNotEmpty) ? phone : null;
    } on PlatformException catch (e) {
      _log('getPendingIncomingCallPeek error: $e');
      return null;
    }
  }

  /// Clear pending incoming call (call after successfully showing overlay).
  Future<void> clearPendingIncomingCall() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('clearPendingIncomingCall');
    } on PlatformException catch (e) {
      _log('clearPendingIncomingCall error: $e');
    }
  }

  /// Read phone from cache file (receiver writes; overlay isolate may not share SharedPreferences).
  /// File is overwritten on each new call; we do not delete so overlay always reads latest.
  static Future<String?> takeStoredPhoneFromFile() async {
    if (!Platform.isAndroid) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_overlayPhoneFile');
      if (!await file.exists()) return null;
      final phone = await file.readAsString();
      return phone.trim().isNotEmpty ? phone.trim() : null;
    } catch (e) {
      _log('takeStoredPhoneFromFile error: $e');
      return null;
    }
  }

  /// Trigger overlay for incoming call. Normalizes phone, stores for overlay, shareData, showOverlay.
  /// Returns true if overlay was shown, false otherwise.
  Future<bool> triggerOverlay(String phone) async {
    if (!Platform.isAndroid) return false;
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) {
      _log('triggerOverlay: empty phone after normalize');
      return false;
    }

    final overlayOk = await isOverlayPermissionGranted();
    if (!overlayOk) {
      _log(
          'Overlay permission not granted, skip. Enable in Profile → Caller ID.');
      return false;
    }

    try {
      await FlutterOverlayWindow.shareData(normalized);
    } catch (e) {
      _log('shareData error: $e');
    }
    // shareData(normalized) immediately above; overlayListener receives it (avoids SharedPreferences sync lag).
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) {
      _log('Overlay permission revoked before showOverlay, skip.');
      return false;
    }
    try {
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Operon Caller ID',
        overlayContent: 'Incoming call',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.none,
        height: 420,
        width: 440,
        alignment: OverlayAlignment.center,
      );
      _log('showOverlay completed for $normalized');
      return true;
    } catch (e, st) {
      _log('showOverlay error: $e');
      _log('$st');
      return false;
    }
  }

  /// Close the overlay (e.g. from overlay Close button).
  Future<void> closeOverlay() async {
    if (!Platform.isAndroid) return;
    await FlutterOverlayWindow.closeOverlay();
  }

  /// Whether Caller ID overlay is enabled (persisted). When false, overlay is not shown on incoming calls.
  Future<bool> isCallerIdEnabled() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyCallerIdEnabled) ?? false;
  }

  /// Enable or disable Caller ID overlay.
  Future<void> setCallerIdEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCallerIdEnabled, enabled);
  }

  /// Push phone to overlay via shareData only (overlay already shown by OverlayService).
  /// Use when receiver started both OverlayService and MainActivity.
  Future<void> shareDataOnlyForOverlay(String phone) async {
    if (!Platform.isAndroid) return;
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) {
      _log('shareDataOnlyForOverlay: empty phone after normalize');
      return;
    }
    try {
      await FlutterOverlayWindow.shareData(normalized);
      _log('shareDataOnlyForOverlay: shareData($normalized) ok');
    } catch (e) {
      _log('shareDataOnlyForOverlay error: $e');
    }
  }

  /// Check for pending call (e.g. app launched by receiver). Push phone via shareData only;
  /// overlay is already shown by OverlayService. No showOverlay.
  Future<bool> checkAndTriggerFromPendingCall() async {
    if (!Platform.isAndroid) return false;
    _log('checkAndTriggerFromPendingCall');
    final enabled = await isCallerIdEnabled();
    _log('Caller ID enabled: $enabled');
    if (!enabled) return false;
    final phone = await getPendingIncomingCallPeek();
    _log(
        'Pending phone: ${phone != null && phone.isNotEmpty ? phone : "null/empty"}');
    if (phone == null || phone.isEmpty) return false;
    await shareDataOnlyForOverlay(phone);
    await clearPendingIncomingCall();
    return true;
  }
}
