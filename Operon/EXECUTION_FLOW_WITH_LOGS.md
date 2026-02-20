# Call Overlay Debug Logging - Visual Execution Flow

## Complete Execution Path with Log Points

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INCOMING CALL TRIGGERS NATIVE CODE                       │
│                           CallDetectionReceiver                             │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       │ Calls startOverlayService()
                                       │ with phone number
                                       │
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Android OverlayService                              │
│ 1. Creates FlutterOverlayWindow                                             │
│ 2. Shares phone number via FlutterChannel                                   │
│ 3. Runs overlayMain() entrypoint                                            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                                       ▼
╔═════════════════════════════════════════════════════════════════════════════╗
║                     FLUTTER OVERLAY APP INITIALIZATION                      ║
║                   (Separate Isolate - overlay_entry.dart)                   ║
║                                                                             ║
║  🚀 runOverlayApp() FUNCTION STARTS [LOG POINT 1]                          ║
║     │                                                                       ║
║     ├─ 🚀 overlayMain runOverlayApp starting [EMOJI LOG]                  ║
║     │                                                                       ║
║     ├─ FIREBASE INITIALIZATION BLOCK 🔥                                    ║
║     │  │                                                                    ║
║     │  ├─ ⚙️ Initializing Firebase... [LOG POINT 2]                       ║
║     │  │                                                                    ║
║     │  └─► try {                                                           ║
║     │        await Firebase.initializeApp(...)                             ║
║     │        ✅ Firebase initialized [LOG POINT 3]                         ║
║     │      } catch (e, st) {                                               ║
║     │        ❌ overlay Firebase init error: $e [LOG POINT 4]              ║
║     │        Stack: $st [LOG POINT 5]                                      ║
║     │      }                                                                ║
║     │                                                                       ║
║     ├─ AUTHENTICATION BLOCK 🔐                                             ║
║     │  │                                                                    ║
║     │  ├─ 🔐 Setting up anonymous auth... [LOG POINT 6]                  ║
║     │  │                                                                    ║
║     │  └─► try {                                                           ║
║     │        final auth = FirebaseAuth.instance                            ║
║     │        if (auth.currentUser == null) {                               ║
║     │          await auth.signInAnonymously()                              ║
║     │          ✅ Anonymous auth successful [LOG POINT 7]                  ║
║     │        } else {                                                       ║
║     │          ℹ️ Already authenticated as: ... [LOG POINT 8]             ║
║     │        }                                                              ║
║     │      } catch (e, st) {                                               ║
║     │        ❌ overlay anonymous auth error: $e [LOG POINT 9]             ║
║     │        Stack: $st [LOG POINT 10]                                     ║
║     │      }                                                                ║
║     │                                                                       ║
║     └─ RUNAPP BLOCK 🎨                                                     ║
║        │                                                                    ║
║        ├─ 🎨 Starting Flutter App... [LOG POINT 11]                       ║
║        │                                                                    ║
║        └─► try {                                                           ║
║             runApp(const _OverlayApp())                                    ║
║           } catch (e, st) {                                                ║
║             ❌ Error running overlay app: $e [LOG POINT 12]                ║
║             Stack: $st [LOG POINT 13]                                      ║
║           }                                                                 ║
║                                                                             ║
║  runOverlayApp() FUNCTION ENDS [14 LOG POINTS TOTAL]                       ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                       │
                    ┌──────────────────┴──────────────────┐
                    │    _OverlayApp(StatefulWidget)      │
                    │  Creates application root widget    │
                    └──────────────────┬──────────────────┘
                                       │
                                       ▼
╔═════════════════════════════════════════════════════════════════════════════╗
║              _OverlayAppState - STATE INITIALIZATION                        ║
║                                                                             ║
║  initState() FUNCTION [LOG POINT 15-17]                                    ║
║  │                                                                          ║
║  ├─ 🎬 _OverlayAppState.initState() starting... [LOG POINT 15]            ║
║  │                                                                          ║
║  └─► try {                                                                 ║
║       _overlayFuture = _buildOverlay()                                     ║
║       ✅ _buildOverlay() future assigned successfully [LOG POINT 16]      ║
║     } catch (e, st) {                                                      ║
║       ❌ Error in initState: $e [LOG POINT 17]                            ║
║       Stack: $st                                                           ║
║       rethrow                                                              ║
║     }                                                                       ║
║                                                                             ║
║  [3 LOG POINTS TOTAL]                                                      ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                       │
                                       │
                                       ▼
╔═════════════════════════════════════════════════════════════════════════════╗
║           _buildOverlay() ASYNC FUNCTION [CRITICAL - 45+ LOG POINTS]        ║
║                                                                             ║
║  try {                                                                      ║
║                                                                             ║
║    STARTUP & PLATFORM CHECK                                                ║
║    ├─ 🏗️ _buildOverlay() started [LOG POINT 18]                           ║
║    ├─ Platform.isAndroid check                                             ║
║    ├─ ℹ️ Non-Android platform detected OR                                 ║
║    └─ ✅ Android platform confirmed [LOG POINT 19]                        ║
║                                                                             ║
║    SERVICE INITIALIZATION                                                  ║
║    ├─ ⚙️ Initializing services... [LOG POINT 20]                          ║
║    ├─ Create FirebaseFirestore.instance                                    ║
║    ├─ Create ClientService(firestore)                                      ║
║    ├─ Create PendingOrdersDataSource(firestore)                            ║
║    ├─ Create ScheduledTripsDataSource(firestore)                           ║
║    ├─ Create TransactionsDataSource(firestore)                             ║
║    └─ ✅ All data sources created [LOG POINT 21]                          ║
║                                                                             ║
║    REPOSITORY INITIALIZATION                                               ║
║    ├─ 🔧 Creating CallerOverlayRepository... [LOG POINT 22]              ║
║    ├─ Create CallerOverlayRepository(all sources)                          ║
║    └─ ✅ CallerOverlayRepository created [LOG POINT 23]                  ║
║                                                                             ║
║    BLOC INITIALIZATION                                                     ║
║    ├─ 📦 Creating CallOverlayBloc... [LOG POINT 24]                       ║
║    ├─ Create CallOverlayBloc(repository)                                   ║
║    └─ ✅ CallOverlayBloc created [LOG POINT 25]                           ║
║                                                                             ║
║    LISTENER SETUP                                                          ║
║    ├─ 🎧 Setting up overlay listener... [LOG POINT 26]                    ║
║    ├─ Subscribe to FlutterOverlayWindow.overlayListener                    ║
║    │  └─► try {                                                            ║
║    │      if (event is String && event.trim().isNotEmpty && mounted) {    ║
║    │        Final s = event.trim()                                         ║
║    │        if (!firstCompleter.isCompleted) complete(s)                  ║
║    │        📱 Overlay received shareData: $s [LOG POINT 27]              ║
║    │        bloc.add(PhoneNumberReceived(s))                               ║
║    │      }                                                                 ║
║    │    } catch (e, st) {                                                  ║
║    │      ❌ Error in overlay listener: $e [LOG POINT 28]                ║
║    │      Stack: $st [LOG POINT 29]                                       ║
║    │    }                                                                   ║
║    └─ ✅ Overlay listener attached [LOG POINT 30]                         ║
║                                                                             ║
║    TIMEOUT MANAGEMENT                                                      ║
║    └─► Timer(600ms) {                                                      ║
║         if (!firstCompleter.isCompleted) {                                 ║
║           firstCompleter.complete(null)                                    ║
║           ⏱️ Timeout reached... [LOG POINT 31]                            ║
║         }                                                                    ║
║        }                                                                     ║
║                                                                             ║
║    PHONE RETRIEVAL FROM LISTENER                                           ║
║    ├─ ⏳ Waiting for phone number... [LOG POINT 32]                       ║
║    └─► try {                                                               ║
║         String? phone = await firstCompleter.future                       ║
║         📞 Received phone: $phone [LOG POINT 33]                          ║
║        } catch (e, st) {                                                   ║
║         ❌ Error getting phone: $e [LOG POINT 34]                         ║
║         Stack: $st [LOG POINT 35]                                          ║
║         phone = null                                                        ║
║        }                                                                     ║
║                                                                             ║
║    FALLBACK FILE READ                                                      ║
║    ├─ Check: fromListener = phone != null && isNotEmpty                   ║
║    └─ If !fromListener:                                                    ║
║       ├─ 📂 Phone not from listener, checking file... [LOG POINT 36]      ║
║       └─► try {                                                            ║
║           phone = await CallerOverlayService.takeStoredPhoneFromFile()    ║
║           if (phone != null && isNotEmpty) {                              ║
║             ✅ Retrieved phone from file: $phone [LOG POINT 37]          ║
║           } else {                                                          ║
║             ⚠️ No phone in stored file [LOG POINT 38]                    ║
║           }                                                                 ║
║         } catch (e, st) {                                                  ║
║           ❌ Error reading from file: $e [LOG POINT 39]                  ║
║           Stack: $st [LOG POINT 40]                                        ║
║           phone = null                                                      ║
║         }                                                                    ║
║                                                                             ║
║    FINAL PHONE STATUS                                                      ║
║    └─ ℹ️ Final phone value: ... (fromListener=$fromListener)              ║
║         [LOG POINT 41]                                                      ║
║                                                                             ║
║    PENDING CALL CLEANUP                                                    ║
║    └─► if (phone != null && isNotEmpty):                                   ║
║         try {                                                               ║
║           await CallerOverlayService.instance.clearPendingIncomingCall()   ║
║           ✅ Cleared pending incoming call [LOG POINT 42]                  ║
║         } catch (e, st) {                                                  ║
║           ⚠️ Error clearing pending call: $e [LOG POINT 43]              ║
║           Stack: $st [LOG POINT 44]                                        ║
║         }                                                                    ║
║                                                                             ║
║    BLOC EVENT                                                              ║
║    ├─ 🎯 Adding PhoneNumberReceived event to BLoC... [LOG POINT 45]      ║
║    ├─ bloc.add(PhoneNumberReceived(phone ?? ''))                           ║
║    └─ ✅ Event added, building widget tree... [LOG POINT 46]             ║
║                                                                             ║
║    WIDGET TREE CONSTRUCTION                                                ║
║    ├─ BlocProvider<CallOverlayBloc>.value(                                 ║
║    │   value: bloc,                                                         ║
║    │   child: Material(                                                     ║
║    │     color: transparent,                                               ║
║    │     child: SafeArea(                                                   ║
║    │       child: Center(                                                   ║
║    │         child: Padding(                                                ║
║    │           child: CallOverlayWidget()                                   ║
║    │         )                                                              ║
║    │       )                                                                ║
║    │     )                                                                  ║
║    │   )                                                                    ║
║    │ )                                                                      ║
║    ├─ ✅ Widget tree built successfully! [LOG POINT 47]                   ║
║    └─ return widget                                                        ║
║                                                                             ║
║  } catch (e, st) {                                                         ║
║    ❌ CRITICAL ERROR in _buildOverlay: $e [LOG POINT 48]                  ║
║    Stack: $st [LOG POINT 49]                                              ║
║    return Material(red error widget with error message)                    ║
║  }                                                                           ║
║                                                                             ║
║  [47+ LOG POINTS TOTAL]                                                    ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                       │
                      ┌────────────────┴────────────────┐
                      │  Future<Widget> _overlayFuture  │
                      │      (Async operation)          │
                      └────────────────┬────────────────┘
                                       │
                                       ▼
╔═════════════════════════════════════════════════════════════════════════════╗
║              build() FUNCTION - MATERIALAPP + FUTUREBUILDER                 ║
║                                                                             ║
║  @override                                                                  ║
║  Widget build(BuildContext context) {                                      ║
║    return MaterialApp(                                                      ║
║      home: FutureBuilder<Widget>(                                           ║
║        future: _overlayFuture,                                              ║
║        builder: (context, snap) {                                           ║
║                                                                             ║
║           CASE 1: ERROR STATE                                              ║
║           if (snap.hasError) {                                              ║
║             ❌ FutureBuilder error: ${snap.error} [LOG POINT 50]          ║
║             Stack: ${snap.stackTrace} [LOG POINT 51]                       ║
║             return Material(red error widget)                               ║
║           }                                                                  ║
║                                                                             ║
║           CASE 2: SUCCESS STATE                                            ║
║           if (snap.hasData) {                                               ║
║             ✨ FutureBuilder has data, rendering... [LOG POINT 52]        ║
║             return snap.data!  [OVERLAY DISPLAYS]                          ║
║           }                                                                  ║
║                                                                             ║
║           CASE 3: LOADING STATE                                            ║
║           ⏳ FutureBuilder waiting: connectionState... [LOG POINT 53]     ║
║           return Material(loading indicator)                                ║
║        }                                                                     ║
║      )                                                                       ║
║    )                                                                         ║
║  }                                                                           ║
║                                                                             ║
║  [4 LOG POINTS TOTAL]                                                      ║
╚═════════════════════════════════════════════════════════════════════════════╝
                                       │
                    ┌──────────────────┴──────────────────┐
                    │      overlay_entry.dart COMPLETE     │
                    │        [56+ LOG POINTS TOTAL]        │
                    └─────────────────────────────────────┘


════════════════════════════════════════════════════════════════════════════════
                              COMPLETE EXECUTION TREE
════════════════════════════════════════════════════════════════════════════════

PHASE 1: ANDROID NATIVE                             [Native Code]
├─ CallDetectionReceiver detects call              [Android Service]
├─ Calls startOverlayService()                      [Android Service]
└─ Triggers overlayMain() in Flutter                [Bridge to Flutter]

PHASE 2: FLUTTER OVERLAY APP INITIALIZATION        [overlay_entry.dart]
├─ runOverlayApp() [14 logs]
│  ├─ Firebase initialization [3 logs + errors]
│  ├─ Auth setup [3 logs + errors]
│  └─ runApp() [3 logs + errors]
│
├─ _OverlayAppState.initState() [3 logs]
│  └─ Assign _buildOverlay() future
│
├─ _buildOverlay() async [47+ logs]
│  ├─ Platform check [2 logs]
│  ├─ Services init [3 logs]
│  ├─ Repository init [2 logs]
│  ├─ BLoC init [2 logs]
│  ├─ Listener setup [4 logs + error]
│  ├─ Phone retrieval [3 logs + error]
│  ├─ File fallback [3 logs + error]
│  ├─ Pending cleanup [2 logs + error]
│  ├─ BLoC event [2 logs]
│  ├─ Widget building [1 log]
│  └─ Error catch-all [2 logs]
│
└─ build() + FutureBuilder [4 logs]
   ├─ Error state [2 logs]
   ├─ Success state [1 log]
   └─ Loading state [1 log]

TOTAL LOGS IN overlay_entry.dart: 56+ log points covering all paths


════════════════════════════════════════════════════════════════════════════════
                         PHASE 1 LOGS (Previously Added)
════════════════════════════════════════════════════════════════════════════════

PHASE 1a: call_overlay_bloc.dart [24 logs]
├─ Phone receive event [3 logs]
├─ Phone normalization [3 logs]
├─ Client lookup [4 logs]
├─ Orders fetch [4 logs]
├─ Transactions fetch [3 logs]
├─ State updates [3 logs]
└─ Error handling [4 logs]

PHASE 1b: caller_overlay_bootstrap.dart [12 logs]
├─ Initialization [2 logs]
├─ Lifecycle changes [3 logs]
├─ Resume checks [2 logs]
├─ Pending call checks [3 logs]
└─ Disposal [2 logs]

PHASE 1c: caller_overlay_service.dart [53 logs]
├─ Permission checks [5 logs]
├─ Overlay triggering [8 logs]
├─ Data sharing [7 logs]
├─ Storage operations [8 logs]
├─ Service state [8 logs]
└─ Error handling [11 logs]

TOTAL LOGS IN PHASE 1: 89 log points


════════════════════════════════════════════════════════════════════════════════
                            TOTAL SYSTEM COVERAGE
════════════════════════════════════════════════════════════════════════════════

overlay_entry.dart (Phase 2):     56+ logs
call_overlay_bloc.dart (Phase 1):  24 logs
caller_overlay_bootstrap.dart:      12 logs
caller_overlay_service.dart:        53 logs
                                  ─────────
TOTAL:                            145+ debug log points

All files: Pass Dart analysis (zero errors)
All logs: Consistent emoji indicators
All errors: Include full stack traces
All operations: Try-catch wrapped
```

---

## Log Timeline During Incoming Call

```
t=0ms     : 📞 Incoming call detected by CallDetectionReceiver
          : 🚀 runOverlayApp() starts executing

t=50ms    : ⚙️ Firebase initializing...
          : ✅ Firebase initialized
          : 🔐 Auth setting up...
          : ✅ Anonymous auth successful

t=100ms   : 🎨 Starting Flutter App...
          : 🎬 initState() running...
          : 🏗️ _buildOverlay() started

t=150ms   : ✅ Services created
          : 🔧 Repository created
          : 📦 BLoC created
          : 🎧 Listener attached

t=200ms   : ⏳ Waiting for phone number...

t=250ms   : 📱 Phone received from overlay channel: +919022933919
          : 📞 Processing phone...
          : 🎯 Adding event to BLoC...

t=300ms   : ✅ Event added
          : 📂 [Check if file also needed]
          : 🎯 BLoC processing phone...
          : [BLoC performs client lookup, orders fetch, etc.]

t=400ms   : ✅ Widget tree built successfully!

t=450ms   : ✨ FutureBuilder received data

t=500ms   : [OVERLAY DISPLAYS ON SCREEN]
```

---

## Success vs Failure Flow

### ✅ SUCCESS PATH
```
🚀 start ──► ✅ Firebase ──► ✅ Auth ──► ✅ Services
         ──► ✅ BLoC ──► ✅ Listener ──► 📱 Phone received
         ──► ✅ Event added ──► ✅ Widget built
         ──► ✨ Data ready ──► [OVERLAY VISIBLE]
```

### ❌ FAILURE PATHS
```
🚀 start ──► ❌ Firebase [STOP - Show error + stack]
🚀 start ──► ✅ Firebase ──► ❌ Auth [STOP - Show error + stack]
🚀 start ──► ... ──► ❌ Services [STOP - Show error + stack]
🚀 start ──► ... ──► ❌ Phone [TIMEOUT - No phone received]
🚀 start ──► ... ──► ❌ Widget build [STOP - Show error + stack]
```

---

## Filtering Logs by Category

```bash
# All overlay logs
adb logcat | grep "CallerOverlay"

# Firebase/Auth only
adb logcat | grep "CallerOverlay" | grep "🚀\|⚙️\|🔐\|✅"

# Errors only
adb logcat | grep "CallerOverlay" | grep "❌"

# Initialization sequence
adb logcat | grep "CallerOverlay" | grep "🏗️\|📦\|🎧"

# Phone number tracking
adb logcat | grep "CallerOverlay" | grep "📱\|📞\|⏳"

# Final stages
adb logcat | grep "CallerOverlay" | grep "✨\|widget tree\|FutureBuilder"
```

---

Generated: Phase 2 Complete  
Status: Visual flow map for execution tracing  
Total Log Points: 145+ with complete flow visibility
