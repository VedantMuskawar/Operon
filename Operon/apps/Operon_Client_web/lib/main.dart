import 'package:core_bloc/core_bloc.dart';
import 'package:dash_web/config/firebase_options.dart';
import 'package:dash_web/presentation/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    
    // Wait for Firebase Auth to restore any existing session
    // This is important for web where auth state persists in IndexedDB
    await FirebaseAuth.instance.authStateChanges().first;
    debugPrint('[main] Firebase Auth state restored');
    
    // Temporarily disable app verification for testing
    // This bypasses reCAPTCHA and device checks
    if (kDebugMode) {
      await FirebaseAuth.instance.setSettings(
        appVerificationDisabledForTesting: true,
      );
      debugPrint('[main] App verification disabled for testing (DEBUG ONLY)');
    }
  } catch (e, stackTrace) {
    debugPrint('[main] Firebase initialization failed: $e');
    debugPrint('[main] Stack trace: $stackTrace');
  }
  
  Bloc.observer = const AppBlocObserver();
  runApp(const DashWebApp());
}
