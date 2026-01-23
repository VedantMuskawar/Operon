import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  PermissionUtils._();

  /// Requests the permissions required for driver tracking:
  /// - Location (When In Use)
  /// - Location (Always) for background tracking
  /// - Notifications (Android 13+)
  ///
  /// Returns `true` only if all required permissions are granted.
  static Future<bool> requestDriverPermissions(BuildContext context) async {
    // 1) Location (When In Use)
    final whenInUseOk = await _ensurePermission(
      context: context,
      permission: Permission.locationWhenInUse,
      title: 'Location permission required',
      message:
          'Operon Driver needs your location to show your position on the map and to track trips accurately.',
    );
    if (!whenInUseOk) return false;
    if (!context.mounted) return false;

    // 2) Location (Always)
    // Android restricts background location requests. We still attempt the request,
    // and fall back to an "Open Settings" flow if the OS blocks it.
    final alwaysStatus = await Permission.locationAlways.status;
    if (!alwaysStatus.isGranted) {
      if (!context.mounted) return false;
      final proceed = await _showPreRequestDialog(
        context,
        title: 'Allow location in the background',
        message:
            'To track trips while the app is in the background, please allow "All the time" location access on the next screen.',
        primaryLabel: 'Continue',
        secondaryLabel: 'Not now',
      );
      if (!proceed) return false;
      if (!context.mounted) return false;

      final requested = await Permission.locationAlways.request();
      if (!requested.isGranted) {
        if (!context.mounted) return false;
        await _showDeniedDialog(
          context,
          title: 'Background location needed',
          message:
              'Background location is required to keep trip tracking running when your screen is off or when you switch apps.\n\nPlease enable "All the time" location access in Settings.',
          offerSettings: true,
        );
        final after = await Permission.locationAlways.status;
        if (!after.isGranted) return false;
      }
    }

    // 3) Notifications
    // On Android < 13 this may be implicitly granted; on 13+ it requires runtime permission.
    if (!context.mounted) return false;
    final notificationOk = await _ensurePermission(
      context: context,
      permission: Permission.notification,
      title: 'Notifications permission required',
      message:
          'Operon Driver uses notifications to keep trip tracking running reliably in the background.',
      allowRestrictedAsOk: true,
    );
    if (!notificationOk) return false;

    return true;
  }

  static Future<bool> _ensurePermission({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String message,
    bool allowRestrictedAsOk = false,
  }) async {
    var status = await permission.status;

    if (status.isGranted) return true;
    if (allowRestrictedAsOk && status.isRestricted) return true;

    if (status.isDenied) {
      status = await permission.request();
    }

    if (status.isGranted) return true;
    if (allowRestrictedAsOk && status.isRestricted) return true;

    // Permanently denied / limited / restricted -> explain + settings.
    if (!context.mounted) return false;
    await _showDeniedDialog(
      context,
      title: title,
      message: message,
      offerSettings: status.isPermanentlyDenied || status.isRestricted || status.isLimited,
    );

    final after = await permission.status;
    if (after.isGranted) return true;
    if (allowRestrictedAsOk && after.isRestricted) return true;
    return false;
  }

  static Future<bool> _showPreRequestDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String primaryLabel,
    required String secondaryLabel,
  }) async {
    if (!context.mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(secondaryLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(primaryLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> _showDeniedDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool offerSettings,
  }) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (offerSettings)
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }
}

