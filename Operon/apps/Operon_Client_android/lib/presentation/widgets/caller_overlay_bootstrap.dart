import 'dart:developer' as developer;
import 'dart:io';

import 'package:dash_mobile/data/services/caller_overlay_service.dart';
import 'package:flutter/material.dart';

void _log(String msg) {
  developer.log(msg, name: 'CallerOverlay.Bootstrap');
}

/// Runs on cold start (initState) and on every app resume.
/// If launched/resumed by CallDetectionReceiver (incoming call), triggers the Caller ID overlay.
class CallerOverlayBootstrap extends StatefulWidget {
  const CallerOverlayBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<CallerOverlayBootstrap> createState() => _CallerOverlayBootstrapState();
}

class _CallerOverlayBootstrapState extends State<CallerOverlayBootstrap>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    _log('🚀 Bootstrap initialized');
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      _log('📱 Android detected. Checking for pending calls...');
      Future.microtask(() => _checkPendingCall());
    } else {
      _log('⚠️  Non-Android platform detected.');
    }
  }

  @override
  void dispose() {
    _log('🛑 Bootstrap disposed');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('♻️  App lifecycle changed: $state');
    if (state != AppLifecycleState.resumed) return;
    if (!Platform.isAndroid) return;
    _log('⏸️  App resumed. Checking for pending calls...');
    Future.microtask(() => _checkPendingCall());
  }

  Future<void> _checkPendingCall() async {
    try {
      _log('🔍 Checking for pending calls...');
      final ok = await CallerOverlayService.instance.checkAndTriggerFromPendingCall();
      _log('✅ Pending call check result: $ok');
    } catch (e, st) {
      _log('❌ Bootstrap error: $e');
      _log('Stack trace: $st');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
