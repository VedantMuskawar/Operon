import 'dart:developer' as developer;
import 'dart:io';

import 'package:dash_mobile/data/services/caller_overlay_service.dart';
import 'package:flutter/material.dart';

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
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isAndroid) {
      Future.microtask(() => _checkPendingCall());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!Platform.isAndroid) return;
    Future.microtask(() => _checkPendingCall());
  }

  Future<void> _checkPendingCall() async {
    try {
      developer.log('Bootstrap: checking pending call...', name: 'CallerOverlay');
      final ok = await CallerOverlayService.instance.checkAndTriggerFromPendingCall();
      developer.log('Bootstrap: checkAndTriggerFromPendingCall => $ok', name: 'CallerOverlay');
    } catch (e, st) {
      developer.log('Bootstrap error: $e', name: 'CallerOverlay');
      developer.log('$st', name: 'CallerOverlay');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
