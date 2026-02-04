import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/config/firebase_options.dart';
import 'package:dash_web/presentation/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Register image_picker web implementation so pickImage has a handler on web
  ImagePickerPlugin.registerWith(webPluginRegistrar);
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[main] Firebase initialized successfully');
    
    // Wait for Firebase Auth to restore any existing session
    // This is important for web where auth state persists in IndexedDB
    try {
      // Simplified: Wait for first auth state change or timeout quickly
      await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
        debugPrint('[main] Auth state check timed out, continuing...');
          return null;
        },
      );
      debugPrint('[main] Firebase Auth state restored');
    } catch (e) {
      // Handle errors gracefully - continue app initialization
      debugPrint('[main] Auth state check error (non-fatal): $e');
    }
    
    // Temporarily disable app verification for testing
    // This bypasses reCAPTCHA and device checks
    if (kDebugMode) {
      try {
        await FirebaseAuth.instance.setSettings(
          appVerificationDisabledForTesting: true,
        );
        debugPrint('[main] App verification disabled for testing (DEBUG ONLY)');
      } catch (e) {
        debugPrint('[main] Failed to disable app verification: $e');
      }
    }
  } catch (e, stackTrace) {
    debugPrint('[main] Firebase initialization failed: $e');
    debugPrint('[main] Stack trace: $stackTrace');
  }
  
  Bloc.observer = const AppBlocObserver();
  runApp(const DashWebApp());
}
