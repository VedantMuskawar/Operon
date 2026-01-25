import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_mobile/config/firebase_options.dart';
import 'package:dash_mobile/data/datasources/pending_orders_data_source.dart';
import 'package:dash_mobile/data/datasources/scheduled_trips_data_source.dart';
import 'package:dash_mobile/data/datasources/transactions_data_source.dart';
import 'package:dash_mobile/data/repositories/caller_overlay_repository.dart';
import 'package:dash_mobile/data/services/caller_overlay_service.dart';
import 'package:dash_mobile/data/services/client_service.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_bloc.dart';
import 'package:dash_mobile/presentation/blocs/call_overlay/call_overlay_event.dart';
import 'package:dash_mobile/presentation/widgets/call_overlay_widget.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Overlay app for Caller ID. Called from main.overlayMain.
/// Overlay runs in a separate isolate; Firebase must be initialized here (not shared with main app).
Future<void> runOverlayApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('overlayMain runOverlayApp', name: 'CallerOverlay');
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    developer.log('overlay Firebase init error: $e', name: 'CallerOverlay');
  }
  runApp(const _OverlayApp());
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
    _overlayFuture = _buildOverlay();
  }

  @override
  void dispose() {
    _overlayListenerSub?.cancel();
    super.dispose();
  }

  Future<Widget> _buildOverlay() async {
    if (!Platform.isAndroid) {
      return const Material(child: Center(child: Text('Caller ID overlay is Android only.')));
    }
    developer.log('overlay _buildOverlay start', name: 'CallerOverlay');
    final firestore = FirebaseFirestore.instance;
    final clientService = ClientService(firestore: firestore);
    final pendingOrders = PendingOrdersDataSource(firestore: firestore);
    final scheduledTrips = ScheduledTripsDataSource(firestore: firestore);
    final transactions = TransactionsDataSource(firestore: firestore);
    final repository = CallerOverlayRepository(
      clientService: clientService,
      pendingOrdersDataSource: pendingOrders,
      scheduledTripsDataSource: scheduledTrips,
      transactionsDataSource: transactions,
    );
    final bloc = CallOverlayBloc(repository: repository);

    final firstCompleter = Completer<String?>();
    _overlayListenerSub = FlutterOverlayWindow.overlayListener.listen((event) {
      if (event is String && event.trim().isNotEmpty && mounted) {
        final s = event.trim();
        if (!firstCompleter.isCompleted) firstCompleter.complete(s);
        developer.log('overlay received shareData: $s', name: 'CallerOverlay');
        bloc.add(PhoneNumberReceived(s));
      }
    });
    Timer(const Duration(milliseconds: 1500), () {
      if (!firstCompleter.isCompleted) firstCompleter.complete(null);
    });

    String? phone;
    try {
      phone = await firstCompleter.future;
    } catch (_) {
      phone = null;
    }
    final fromListener = phone != null && phone.isNotEmpty;
    if (!fromListener) {
      phone = await CallerOverlayService.takeStoredPhoneFromFile();
    }
    if (phone == null || phone.isEmpty) {
      phone = await CallerOverlayService.takeStoredPhone();
    }
    developer.log('overlay phone: ${phone != null && phone.isNotEmpty ? phone : "null/empty"} (fromListener=$fromListener)', name: 'CallerOverlay');
    bloc.add(PhoneNumberReceived(phone ?? ''));
    return BlocProvider<CallOverlayBloc>.value(
      value: bloc,
      child: const Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: CallOverlayWidget(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: FutureBuilder<Widget>(
        future: _overlayFuture,
        builder: (context, snap) {
          if (snap.hasData) return snap.data!;
          return const Material(
            color: Colors.transparent,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        },
      ),
    );
  }
}
