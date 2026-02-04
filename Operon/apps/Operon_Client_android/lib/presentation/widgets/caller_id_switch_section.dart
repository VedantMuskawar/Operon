import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:core_ui/core_ui.dart';
import 'package:dash_mobile/data/services/caller_overlay_service.dart';
import 'package:dash_mobile/shared/constants/app_spacing.dart';
import 'package:flutter/material.dart';

void _log(String msg) {
  developer.log(msg, name: 'CallerOverlay');
}

/// Caller ID switch for Profile section. Requests overlay + phone permissions
/// when turned on.
class CallerIdSwitchSection extends StatefulWidget {
  const CallerIdSwitchSection({super.key});

  @override
  State<CallerIdSwitchSection> createState() => _CallerIdSwitchSectionState();
}

class _CallerIdSwitchSectionState extends State<CallerIdSwitchSection>
    with WidgetsBindingObserver {
  final _service = CallerOverlayService.instance;
  bool _enabled = false;
  bool _loading = true;

  static const _overlayPermissionTimeout = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    if (!Platform.isAndroid) {
      _loading = false;
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!Platform.isAndroid) return;
    _load();
  }

  Future<void> _load() async {
    final enabled = await _service.isCallerIdEnabled();
    _log('_load isCallerIdEnabled=$enabled');
    if (mounted) setState(() => _enabled = enabled);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _onChanged(bool value) async {
    if (!Platform.isAndroid) return;
    try {
      if (value) {
        final phone = await _service.requestPhonePermission();
        if (!phone) {
          _log('_onChanged: phone not granted');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Phone permission is required for Caller ID.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
        _log('_onChanged: requesting overlay permission (timeout ${_overlayPermissionTimeout.inSeconds}s)');
        bool? overlay;
        try {
          overlay = await _service.requestOverlayPermission()
              .timeout(_overlayPermissionTimeout);
        } on TimeoutException {
          _log('_onChanged: requestOverlayPermission timed out');
          overlay = null;
        }
        _log('_onChanged: requestOverlayPermission => $overlay');

        if (overlay != true) {
          final fallback = await _service.isOverlayPermissionGranted();
          _log('_onChanged: fallback isOverlayPermissionGranted=$fallback');
          if (fallback) {
            overlay = true;
          }
        }

        if (overlay != true) {
          _log('_onChanged: overlay not granted, showing SnackBar');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Enable \'Display over other apps\' in Settings for this app, '
                  'then toggle the switch again.',
                ),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        _log('_onChanged: setCallerIdEnabled(true)');
        await _service.setCallerIdEnabled(true);
        if (mounted) setState(() => _enabled = true);
      } else {
        await _service.setCallerIdEnabled(false);
        if (mounted) setState(() => _enabled = false);
      }
    } catch (e, st) {
      _log('_onChanged error: $e');
      developer.log('$st', name: 'CallerOverlay');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not enable Caller ID. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
        child: Row(
          children: [
            Icon(Icons.phone_in_talk, color: AuthColors.textDisabled, size: 22),
            const SizedBox(width: AppSpacing.paddingLG),
            Text(
              'Caller ID',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.paddingMD),
      child: Row(
        children: [
          Icon(
            Icons.phone_in_talk,
            color: AuthColors.textMain,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.paddingLG),
          Expanded(
            child: Text(
              'Caller ID',
              style: TextStyle(
                color: AuthColors.textMain,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                fontFamily: 'SF Pro Display',
              ),
            ),
          ),
          Switch(
            value: _enabled,
            onChanged: _onChanged,
            activeTrackColor: AuthColors.primary,
            activeThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
