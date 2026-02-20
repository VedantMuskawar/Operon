import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/firebase_options.dart';
import 'package:dash_mobile/data/datasources/pending_orders_data_source.dart';
import 'package:dash_mobile/data/datasources/scheduled_trips_data_source.dart';
import 'package:dash_mobile/data/datasources/transactions_data_source.dart';
import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/data/services/caller_overlay_service.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_bloc.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_event.dart';
import 'package:dash_mobile/presentation/widgets/call_overlay_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';

// File-based persistent logging (survives isolate termination)
File? _logFile;

Future<void> _initFileLogging() async {
  try {
    final tempDir = await getTemporaryDirectory();
    _logFile = File('${tempDir.path}/overlay_diagnostic.log');
    await _logFile?.writeAsString('=== OVERLAY DIAGNOSTICS STARTED ===\n', mode: FileMode.append);
  } catch (e) {
    print('Failed to init file logging: $e');
  }
}

void _writeToFile(String msg) {
  try {
    _logFile?.writeAsStringSync('$msg\n', mode: FileMode.append);
  } catch (_) {}
}

Future<String> _readLogFile() async {
  try {
    if (_logFile?.existsSync() ?? false) {
      return await _logFile!.readAsString();
    }
    return '[No log file found]';
  } catch (e) {
    return '[Error reading logs: $e]';
  }
}

// Immediate diagnostic logging (writes to stderr, file, and logcat)
void _logDiagnostic(String msg) {
  final timestamp = DateTime.now().toIso8601String();
  final fullMsg = '🔵 [$timestamp] $msg';
  
  // Try stderr (unbuffered)
  try {
    stderr.writeln(fullMsg);
    stderr.writeCharCode(10); // Extra newline
  } catch (_) {}
  
  // Try print (buffered but backup)
  try {
    print(fullMsg);
  } catch (_) {}
  
  // Try file (persistent)
  try {
    _writeToFile(fullMsg);
  } catch (_) {}
}

/// Overlay app for Caller ID. Called from main.overlayMain.
/// Overlay runs in a separate isolate; Firebase must be initialized here (not shared with main app).
Future<void> runOverlayApp() async {
  // FIRST THING: Write to file immediately, before anything else
  try {
    final tempDir = await getTemporaryDirectory();
    final logFile = File('${tempDir.path}/overlay_diagnostic.log');
    await logFile.writeAsString(
      '=== OVERLAY STARTED ===\n'
      'Time: ${DateTime.now().toIso8601String()}\n'
      'FIRST_WRITE_SUCCESS: runOverlayApp() entry point reached\n\n',
      mode: FileMode.append,
    );
  } catch (e) {
    print('🔴 CRITICAL: Cannot write to file: $e');
  }
  
  _logDiagnostic('STEP_0: runOverlayApp() called - initializing file logging');
  await _initFileLogging();
  _logDiagnostic('STEP_1: File logging initialized, runOverlayApp() entered');
  
  try {
    _logDiagnostic('STEP_2: About to call WidgetsFlutterBinding.ensureInitialized()');
    WidgetsFlutterBinding.ensureInitialized();
    _logDiagnostic('STEP_3: WidgetsFlutterBinding initialized successfully');
  } catch (e, st) {
    _logDiagnostic('STEP_ERROR_WFB: WidgetsFlutterBinding failed: $e');
    _logDiagnostic('STACK: $st');
    rethrow;
  }
  
  try {
    _logDiagnostic('STEP_4: Setting up error handler');
    FlutterError.onError = (details) {
      _logDiagnostic('🔴 FLUTTER_ERROR: ${details.exceptionAsString()}');
      stderr.writeln('🔴 CONTEXT: ${details.context}');
    };
    _logDiagnostic('STEP_5: Error handler set');
  } catch (e) {
    _logDiagnostic('STEP_ERROR_EH: Error handler setup failed: $e');
  }
  
  _logDiagnostic('STEP_6: Calling developer.log startup');
  developer.log('🚀 overlayMain runOverlayApp starting', name: 'CallerOverlay');
  
  try {
    _logDiagnostic('STEP_7: Initializing Firebase');
    developer.log('⚙️ Initializing Firebase...', name: 'CallerOverlay');
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    _logDiagnostic('STEP_8: Firebase initialized');
    developer.log('✅ Firebase initialized', name: 'CallerOverlay');
  } catch (e, st) {
    _logDiagnostic('STEP_ERROR_FB: Firebase init failed: $e');
    _logDiagnostic('STACK_FB: $st');
    developer.log('❌ overlay Firebase init error: $e', name: 'CallerOverlay');
    developer.log('Stack: $st', name: 'CallerOverlay');
  }
  
  try {
    _logDiagnostic('STEP_9: Setting up anonymous auth');
    developer.log('🔐 Setting up anonymous auth...', name: 'CallerOverlay');
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
      _logDiagnostic('STEP_10: Anonymous auth successful');
      developer.log('✅ Anonymous auth successful', name: 'CallerOverlay');
    } else {
      _logDiagnostic('STEP_10_ALT: Already authenticated');
      developer.log('ℹ️  Already authenticated as: ${auth.currentUser?.uid}', name: 'CallerOverlay');
    }
  } catch (e, st) {
    _logDiagnostic('STEP_ERROR_AUTH: Auth failed: $e');
    _logDiagnostic('STACK_AUTH: $st');
    developer.log('❌ overlay anonymous auth error: $e', name: 'CallerOverlay');
    developer.log('Stack: $st', name: 'CallerOverlay');
  }
  
  try {
    _logDiagnostic('STEP_11: About to call runApp');
    developer.log('🎨 Starting Flutter App...', name: 'CallerOverlay');
    
    // Set up global error handler to catch Framework errors
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      _logDiagnostic('FRAMEWORK_ERROR: ${details.exceptionAsString()}');
      developer.log('❌ Flutter Framework Error: ${details.summary}', name: 'CallerOverlay');
      stderr.writeln('🔴 FRAMEWORK_ERROR: ${details.exceptionAsString()}');
      originalOnError?.call(details);
    };
    
    print('🟢 [A] About to call runApp(_OverlayApp())');
    stderr.writeln('🟢 [A] About to call runApp(_OverlayApp())');
    runApp(const _OverlayApp());
    print('🟢 [B] runApp() returned (unusual)');
    _logDiagnostic('STEP_12: runApp() returned (unusual)');
  } catch (e, st) {
    print('🔴 [CRASH_IN_RUNAPP] Exception in runApp: $e');
    stderr.writeln('🔴 [CRASH_IN_RUNAPP] Exception in runApp: $e');
    stderr.writeln('Stack: $st');
    _logDiagnostic('STEP_ERROR_RUN: runApp failed: $e');
    _logDiagnostic('STACK_RUN: $st');
    developer.log('❌ Error running overlay app: $e', name: 'CallerOverlay');
    developer.log('Stack: $st', name: 'CallerOverlay');
  }
}

/// Guarded wrapper that catches exceptions from CallOverlayWidget after it builds
class _GuardedCallOverlay extends StatefulWidget {
  final Widget child;
  
  const _GuardedCallOverlay({required this.child});

  @override
  State<_GuardedCallOverlay> createState() => _GuardedCallOverlayState();
}

class _GuardedCallOverlayState extends State<_GuardedCallOverlay> {
  @override
  void initState() {
    super.initState();
    _logDiagnostic('GUARD_INIT: Guard wrapper initialized');
    // Post-frame callback to detect immediate crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logDiagnostic('GUARD_FRAME: Guard wrapper frame rendered');
    });
  }

  @override
  void didUpdateWidget(_GuardedCallOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _logDiagnostic('GUARD_UPDATE: Guard wrapper updated');
  }

  @override
  void dispose() {
    _logDiagnostic('GUARD_DISPOSE: Guard wrapper disposing');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logDiagnostic('GUARD_BUILD: Building guarded widget');
    try {
      return widget.child;
    } catch (e, st) {
      _logDiagnostic('GUARD_ERROR: Exception in guard wrapper: $e');
      _logDiagnostic('GUARD_STACK: $st');
      return Material(
        color: Colors.red.shade700,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('GUARD ERROR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                Text(e.toString(), style: const TextStyle(color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class _OverlayApp extends StatefulWidget {
  const _OverlayApp();

  @override
  State<_OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<_OverlayApp> {
  late final Future<Widget> _overlayFuture;
  StreamSubscription<dynamic>? _overlayListenerSub;

  @override
  void initState() {
    super.initState();
    _logDiagnostic('WIDGET_INIT_STATE: _OverlayAppState.initState() called');
    try {
      developer.log('🎬 _OverlayAppState.initState() starting...', name: 'CallerOverlay');
      _overlayFuture = _buildOverlay();
      _logDiagnostic('WIDGET_INIT_STATE_SUCCESS: _buildOverlay assigned');
      developer.log('✅ _buildOverlay() future assigned successfully', name: 'CallerOverlay');
      
      // Schedule post-frame callback to log when rendering is complete
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _logDiagnostic('POST_FRAME_CALLBACK: Widget rendered, frame complete');
        developer.log('🎨 Widget rendered, frame callback executed', name: 'CallerOverlay');
      });
    } catch (e, st) {
      _logDiagnostic('WIDGET_INIT_STATE_ERROR: $e');
      developer.log('❌ Error in initState: $e', name: 'CallerOverlay');
      developer.log('Stack: $st', name: 'CallerOverlay');
      rethrow;
    }
  }

  @override
  void dispose() {
    _logDiagnostic('WIDGET_DISPOSE: _OverlayAppState.dispose() called');
    developer.log('🚪 Widget disposing...', name: 'CallerOverlay');
    _overlayListenerSub?.cancel();
    super.dispose();
  }
  
  Widget _buildSafeCallOverlayWidget() {
    try {
      _logDiagnostic('BUILDING_CALL_OVERLAY_WIDGET: Creating CallOverlayWidget');
      return _GuardedCallOverlay(
        child: const CallOverlayWidget(),
      );
    } catch (e, st) {
      _logDiagnostic('ERROR_BUILDING_WIDGET: $e');
      _logDiagnostic('ERROR_STACK: $st');
      return Material(
        color: Colors.orange.shade900,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Widget Build Error', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(e.toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<Widget> _buildOverlay() async {
    try {
      _logDiagnostic('BUILD_OVERLAY_1: _buildOverlay() started');
      developer.log('🏗️ _buildOverlay() started', name: 'CallerOverlay');
      
      if (!Platform.isAndroid) {
        developer.log('ℹ️ Non-Android platform detected', name: 'CallerOverlay');
        return const Material(
            child: Center(child: Text('Caller ID overlay is Android only.')));
      }
      developer.log('✅ Android platform confirmed', name: 'CallerOverlay');
      
      developer.log('⚙️ Initializing services...', name: 'CallerOverlay');
      final firestore = FirebaseFirestore.instance;
      final clientService = ClientService(firestore: firestore);
      final pendingOrders = PendingOrdersDataSource(firestore: firestore);
      final scheduledTrips = ScheduledTripsDataSource(firestore: firestore);
      final transactions = TransactionsDataSource(firestore: firestore);
      developer.log('✅ All data sources created', name: 'CallerOverlay');
      
      developer.log('🔧 Creating CallerOverlayRepository...', name: 'CallerOverlay');
      final repository = CallerOverlayRepository(
        clientService: clientService,
        pendingOrdersDataSource: pendingOrders,
        scheduledTripsDataSource: scheduledTrips,
        transactionsDataSource: transactions,
      );
      developer.log('✅ CallerOverlayRepository created', name: 'CallerOverlay');
      
      developer.log('📦 Creating CallOverlayBloc...', name: 'CallerOverlay');
      final bloc = CallOverlayBloc(repository: repository);
      developer.log('✅ CallOverlayBloc created', name: 'CallerOverlay');

      developer.log('🎧 Setting up overlay listener...', name: 'CallerOverlay');
      final firstCompleter = Completer<String?>();
      _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
        try {
          if (event is String && event.trim().isNotEmpty && mounted) {
            final s = event.trim();
            if (!firstCompleter.isCompleted) firstCompleter.complete(s);
            developer.log('📱 Overlay received shareData: $s', name: 'CallerOverlay');
            bloc.add(PhoneNumberReceived(s));
          }
        } catch (e, st) {
          developer.log('❌ Error in overlay listener: $e', name: 'CallerOverlay');
          developer.log('Stack: $st', name: 'CallerOverlay');
        }
      });
      developer.log('✅ Overlay listener attached', name: 'CallerOverlay');
      
      Timer(const Duration(milliseconds: 600), () {
        if (!firstCompleter.isCompleted) {
          firstCompleter.complete(null);
          developer.log('⏱️ Timeout reached, completing firstCompleter with null', name: 'CallerOverlay');
        }
      });

      developer.log('⏳ Waiting for phone number from listener or timeout...', name: 'CallerOverlay');
      String? phone;
      try {
        phone = await firstCompleter.future;
        developer.log('📞 Received phone: $phone', name: 'CallerOverlay');
      } catch (e, st) {
        developer.log('❌ Error getting phone from listener: $e', name: 'CallerOverlay');
        developer.log('Stack: $st', name: 'CallerOverlay');
        phone = null;
      }
      
      final fromListener = phone != null && phone.isNotEmpty;
      if (!fromListener) {
        developer.log('📂 Phone not from listener, checking stored file...', name: 'CallerOverlay');
        try {
          phone = await CallerOverlayService.takeStoredPhoneFromFile();
          if (phone != null && phone.isNotEmpty) {
            developer.log('✅ Retrieved phone from file: $phone', name: 'CallerOverlay');
          } else {
            developer.log('⚠️ No phone in stored file', name: 'CallerOverlay');
          }
        } catch (e, st) {
          developer.log('❌ Error reading from file: $e', name: 'CallerOverlay');
          developer.log('Stack: $st', name: 'CallerOverlay');
          phone = null;
        }
      }
      
      developer.log(
          'ℹ️ Final phone value: ${phone != null && phone.isNotEmpty ? phone : "null/empty"} (fromListener=$fromListener)',
          name: 'CallerOverlay');
      
      if (phone != null && phone.isNotEmpty) {
        try {
          await CallerOverlayService.instance.clearPendingIncomingCall();
          developer.log('✅ Cleared pending incoming call', name: 'CallerOverlay');
        } catch (e, st) {
          developer.log('⚠️ Error clearing pending call: $e', name: 'CallerOverlay');
          developer.log('Stack: $st', name: 'CallerOverlay');
        }
      }
      
      developer.log('🎯 Adding PhoneNumberReceived event to BLoC...', name: 'CallerOverlay');
      bloc.add(PhoneNumberReceived(phone ?? ''));
      developer.log('✅ Event added, building widget tree...', name: 'CallerOverlay');
      
      final widget = BlocProvider<CallOverlayBloc>.value(
        value: bloc,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _buildSafeCallOverlayWidget(),
              ),
            ),
          ),
        ),
      );
      developer.log('✅ Widget tree built successfully!', name: 'CallerOverlay');
      return widget;
    } catch (e, st) {
      _logDiagnostic('CRITICAL: Exception during _buildOverlay: $e');
      _logDiagnostic('STACK: $st');
      developer.log('❌ CRITICAL ERROR in _buildOverlay: $e', name: 'CallerOverlay');
      developer.log('Stack: $st', name: 'CallerOverlay');
      
      // Return a FutureBuilder that displays error + log file contents
      return Material(
        color: Colors.red.shade900,
        child: FutureBuilder<String>(
          future: _readLogFile(),
          builder: (ctx, logSnap) {
            final logs = logSnap.data ?? '[Logs unavailable]';
            final errorMsg = e.toString();
            final stackStr = st.toString().split('\n').take(8).join('\n');
            
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ OVERLAY INITIALIZATION FAILED',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text('ERROR:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(
                        errorMsg,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      const Text('STACK:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(
                        stackStr,
                        style: const TextStyle(color: Colors.yellow, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      const Text('DIAGNOSTIC LOGS:', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      Container(
                        color: Colors.black38,
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          logs.split('\n').take(20).join('\n'),
                          style: const TextStyle(color: Colors.cyan, fontSize: 9, fontFamily: 'monospace'),
                          maxLines: 20,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _logDiagnostic('WIDGET_BUILD: _OverlayAppState.build() called');
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FutureBuilder<Widget>(
        future: _overlayFuture,
        builder: (context, snap) {
          if (snap.hasError) {
            _logDiagnostic('BUILD_ERROR: FutureBuilder has error: ${snap.error}');
            developer.log('❌ FutureBuilder error: ${snap.error}', name: 'CallerOverlay');
            developer.log('Stack: ${snap.stackTrace}', name: 'CallerOverlay');
            return Material(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Error: ${snap.error}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }
          
          if (snap.hasData) {
            _logDiagnostic('BUILD_SUCCESS: FutureBuilder has data, rendering widget');
            developer.log('✨ FutureBuilder has data, rendering overlay', name: 'CallerOverlay');
            return snap.data!;
          }
          
          _logDiagnostic('BUILD_LOADING: FutureBuilder waiting: ${snap.connectionState}');
          developer.log('⏳ FutureBuilder waiting: connectionState=${snap.connectionState}', name: 'CallerOverlay');
          return const Material(
            color: Colors.transparent,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}
