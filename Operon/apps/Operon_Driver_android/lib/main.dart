import 'package:core_bloc/core_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:operon_driver_android/config/firebase_options.dart';
import 'package:operon_driver_android/presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('[main] Firebase initialized successfully');

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
  runApp(const OperonDriverApp());
}
