import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/firebase_options.dart';
import 'package:dash_mobile/overlay_entry.dart' show runOverlayApp;
import 'package:dash_mobile/presentation/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
// import 'package:firebase_app_check/firebase_app_check.dart';  // Temporarily disabled
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[main] Firebase initialized successfully');

    // Temporarily disable app verification for testing
    // This bypasses reCAPTCHA and device checks
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      debugPrint('[main] App verification disabled for testing (DEBUG ONLY)');
    }

    // // Initialize Firebase App Check
    // try {
    //   if (kDebugMode) {
    //     await FirebaseAppCheck.instance.activate(
    //       androidProvider: AndroidProvider.debug,
    //     );
    //     debugPrint('[main] App Check activated with debug provider');
    //   } else {
    //     await FirebaseAppCheck.instance.activate(
    //       androidProvider: AndroidProvider.playIntegrity,
    //     );
    //     debugPrint('[main] App Check activated with Play Integrity provider');
    //   }
    // } catch (e) {
    //   debugPrint('[main] App Check initialization failed: $e');
    //   // Continue even if App Check fails - it's not critical for basic functionality
    // }
  } catch (e, stackTrace) {
    debugPrint('[main] Firebase initialization failed: $e');
    debugPrint('[main] Stack trace: $stackTrace');
  }

  Bloc.observer = const AppBlocObserver();
  runApp(const DashMobileApp());
}

/// Overlay entry point for Caller ID. Invoked by flutter_overlay_window when overlay is shown.
@pragma('vm:entry-point')
void overlayMain() {
  // IMMEDIATE logging to ensure this is called
  try {
    print('🟢 [1] overlayMain() CALLED - Entry point reached');
    stderr.writeln('🟢 [1] overlayMain() CALLED - Entry point reached');
  } catch (_) {}
  
  try {
    print('🟢 [2] overlayMain() - About to call runOverlayApp()');
    stderr.writeln('🟢 [2] overlayMain() - About to call runOverlayApp()');
    
    // runOverlayApp is async but calls runApp() which blocks forever
    // We don't await it, just kick it off
    runOverlayApp().onError((error, stackTrace) {
      print('🔴 [X] CRITICAL: runOverlayApp failed: $error');
      print('Stack: $stackTrace');
      stderr.writeln('🔴 [X] CRITICAL: runOverlayApp failed: $error');
      stderr.writeln('Stack: $stackTrace');
    });
    print('🟢 [3] overlayMain() - runOverlayApp() initiated'); 
    stderr.writeln('🟢 [3] overlayMain() - runOverlayApp() initiated');
  } catch (e, st) {
    print('🔴 CRITICAL: overlayMain crashed: $e');
    print('Stack: $st');
    stderr.writeln('🔴 CRITICAL: overlayMain crashed: $e');
    stderr.writeln('Stack: $st');
  }
}
