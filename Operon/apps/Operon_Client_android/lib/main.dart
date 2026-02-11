import 'dart:io';

import 'package:core_bloc/core_bloc.dart';
import 'package:dash_mobile/config/firebase_options.dart';
import 'package:dash_mobile/overlay_entry.dart' show runOverlayApp;
import 'package:dash_mobile/presentation/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_app_check/firebase_app_check.dart';  // Temporarily disabled
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // #region agent log
  try {
    File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync(
        '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"A","location":"main.dart:11","message":"main() entry","data":{"platform":"$defaultTargetPlatform"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
        mode: FileMode.append);
  } catch (_) {}
  // #endregion

  try {
    // #region agent log
    try {
      File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync(
          '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"main.dart:14","message":"Before Firebase.initializeApp","data":{},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
          mode: FileMode.append);
    } catch (_) {}
    // #endregion
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // #region agent log
    try {
      File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').writeAsStringSync(
          '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"B","location":"main.dart:18","message":"After Firebase.initializeApp","data":{"appName":"${Firebase.app().name}"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
          mode: FileMode.append);
    } catch (_) {}
    // #endregion
    debugPrint('[main] Firebase initialized successfully');

    // Temporarily disable app verification for testing
    // This bypasses reCAPTCHA and device checks
    if (kDebugMode) {
      // #region agent log
      try {
        File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log')
            .writeAsStringSync(
                '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"main.dart:23","message":"Before setSettings appVerificationDisabled","data":{},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
                mode: FileMode.append);
      } catch (_) {}
      // #endregion
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      // #region agent log
      try {
        File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log')
            .writeAsStringSync(
                '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"C","location":"main.dart:26","message":"After setSettings appVerificationDisabled","data":{},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
                mode: FileMode.append);
      } catch (_) {}
      // #endregion
      debugPrint('[main] App verification disabled for testing (DEBUG ONLY)');
    }

    // #region agent log
    try {
      // Check if App Check is somehow still accessible (Hypothesis D/E)
      try {
        // This will throw if firebase_app_check is not available
        final appCheckRef = Firebase.app().name;
        File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log')
            .writeAsStringSync(
                '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"D","location":"main.dart:30","message":"App Check availability check","data":{"firebaseAppName":"$appCheckRef","appCheckImportCommented":true},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
                mode: FileMode.append);
      } catch (e) {
        File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log')
            .writeAsStringSync(
                '${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').readAsStringSync()}${File('/Users/vedantreddymuskawar/Operon/.cursor/debug.log').existsSync() ? '\n' : ''}{"sessionId":"debug-session","runId":"run1","hypothesisId":"D","location":"main.dart:30","message":"App Check not accessible","data":{"error":"$e"},"timestamp":${DateTime.now().millisecondsSinceEpoch}}\n',
                mode: FileMode.append);
      }
    } catch (_) {}
    // #endregion

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
  runOverlayApp();
}
