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
    _log('🔍 Checking if overlay can run...');
    final overlay = await isOverlayPermissionGranted();
    final phone = await isPhonePermissionGranted();
    _log('📋 Overlay permission: $overlay');
    _log('📋 Phone permission: $phone');
    final canRun = overlay && phone;
    _log('✅ Can run overlay: $canRun');
    return canRun;
  }

  /// Get pending incoming phone from native (when app launched by CallDetectionReceiver).
  /// Returns phone string or null, and clears pending state.
  Future<String?> getPendingIncomingCall() async {
    if (!Platform.isAndroid) return null;
    try {
      _log('💬 Fetching pending incoming call...');
      final phone =
          await _channel.invokeMethod<String>('getPendingIncomingCall');
      final result = (phone != null && phone.isNotEmpty) ? phone : null;
      _log('📞 Pending call result: ${result ?? 'null'}');
      return result;
    } on PlatformException catch (e) {
      _log('❌ getPendingIncomingCall error: $e');
      return null;
    }
  }

  /// Peek pending incoming phone without clearing. Use [clearPendingIncomingCall] after successful trigger.
  Future<String?> getPendingIncomingCallPeek() async {
    if (!Platform.isAndroid) return null;
    try {
      _log('👀 Peeking pending incoming call (non-destructive)...');
      final phone =
          await _channel.invokeMethod<String>('getPendingIncomingCallPeek');
      final result = (phone != null && phone.isNotEmpty) ? phone : null;
      _log('📞 Peek result: ${result ?? 'null'}');
      return result;
    } on PlatformException catch (e) {
      _log('❌ getPendingIncomingCallPeek error: $e');
      return null;
    }
  }

  /// Clear pending incoming call (call after successfully showing overlay).
  Future<void> clearPendingIncomingCall() async {
    if (!Platform.isAndroid) return;
    try {
      _log('🗑️  Clearing pending incoming call...');
      await _channel.invokeMethod('clearPendingIncomingCall');
      _log('✅ Pending call cleared');
    } on PlatformException catch (e) {
      _log('❌ clearPendingIncomingCall error: $e');
    }
  }

  /// Read phone from cache file (receiver writes; overlay isolate may not share SharedPreferences).
  /// File is overwritten on each new call; we do not delete so overlay always reads latest.
  static Future<String?> takeStoredPhoneFromFile() async {
    if (!Platform.isAndroid) return null;
    try {
      _log('📂 Reading phone from cache file...');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$_overlayPhoneFile');
      final exists = await file.exists();
      _log('📁 Cache file exists: $exists');
      if (!exists) {
        _log('⚠️  No cached phone file found');
        return null;
      }
      final phone = await file.readAsString();
      _log('✅ Read phone from file: ${phone.isNotEmpty ? phone.trim() : 'empty'}');
      return phone.trim().isNotEmpty ? phone.trim() : null;
    } catch (e) {
      _log('❌ takeStoredPhoneFromFile error: $e');
      return null;
    }
  }

  /// Trigger overlay for incoming call. Normalizes phone, stores for overlay, shareData, showOverlay.
  /// Returns true if overlay was shown, false otherwise.
  Future<bool> triggerOverlay(String phone) async {
    if (!Platform.isAndroid) return false;
    _log('🎬 Triggering overlay for phone: $phone');
    final normalized = normalizePhone(phone);
    _log('📞 Normalized phone: $normalized');
    if (normalized.isEmpty) {
      _log('⚠️  Empty phone after normalize, skipping overlay trigger');
      return false;
    }

    final overlayOk = await isOverlayPermissionGranted();
    _log('📋 Overlay permission granted: $overlayOk');
    if (!overlayOk) {
      _log(
          '❌ Overlay permission not granted. Enable in Profile → Caller ID.');
      return false;
    }

    try {
      _log('📡 Sharing data with overlay window...');
      await FlutterOverlayWindow.shareData(normalized);
      _log('✅ Data shared successfully');
    } catch (e) {
      _log('⚠️  shareData error: $e');
    }
    // shareData(normalized) immediately above; overlayListener receives it (avoids SharedPreferences sync lag).
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    _log('📋 Final overlay permission check: $granted');
    if (!granted) {
      _log('❌ Overlay permission revoked before showOverlay, skipping.');
      return false;
    }
    try {
      _log('🖼️  Showing overlay window...');
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
      _log('✅ Overlay displayed successfully for $normalized');
      return true;
    } catch (e, st) {
      _log('❌ showOverlay error: $e');
      _log('Stack: $st');
      return false;
    }
  }

  /// Close the overlay (e.g. from overlay Close button).
  Future<void> closeOverlay() async {
    if (!Platform.isAndroid) return;
    _log('🔴 Closing overlay...');
    await FlutterOverlayWindow.closeOverlay();
    _log('✅ Overlay closed');
  }

  /// Whether Caller ID overlay is enabled (persisted). When false, overlay is not shown on incoming calls.
  Future<bool> isCallerIdEnabled() async {
    if (!Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyCallerIdEnabled) ?? false;
    _log('🔍 Caller ID enabled: $enabled');
    return enabled;
  }

  /// Enable or disable Caller ID overlay.
  Future<void> setCallerIdEnabled(bool enabled) async {
    _log('⚙️  Setting Caller ID enabled: $enabled');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCallerIdEnabled, enabled);
    _log('✅ Caller ID enabled state saved: $enabled');
  }

  /// Push phone to overlay via shareData only (overlay already shown by OverlayService).
  /// Use when receiver started both OverlayService and MainActivity.
  Future<void> shareDataOnlyForOverlay(String phone) async {
    if (!Platform.isAndroid) return;
    final normalized = normalizePhone(phone);
    _log('📡 Sharing data only (overlay already shown): $normalized');
    if (normalized.isEmpty) {
      _log('⚠️  Empty phone after normalize, skipping share');
      return;
    }
    try {
      await FlutterOverlayWindow.shareData(normalized);
      _log('✅ Data shared successfully: $normalized');
    } catch (e) {
      _log('❌ shareDataOnlyForOverlay error: $e');
    }
  }

  /// Check for pending call (e.g. app launched by receiver). Push phone via shareData only;
  /// overlay is already shown by OverlayService. No showOverlay.
  Future<bool> checkAndTriggerFromPendingCall() async {
    if (!Platform.isAndroid) return false;
    _log('🔍 Checking for pending incoming call...');
    final enabled = await isCallerIdEnabled();
    _log('📋 Caller ID enabled: $enabled');
    if (!enabled) {
      _log('❌ Caller ID disabled, skipping pending call check');
      return false;
    }
    final phone = await getPendingIncomingCallPeek();
    _log(
        '📞 Pending phone: ${phone != null && phone.isNotEmpty ? phone : "none"}');
    if (phone == null || phone.isEmpty) {
      _log('⚠️  No pending call found');
      return false;
    }
    _log('✅ Pending call found, sharing data with overlay');
    await shareDataOnlyForOverlay(phone);
    await clearPendingIncomingCall();
    return true;
  }
}
