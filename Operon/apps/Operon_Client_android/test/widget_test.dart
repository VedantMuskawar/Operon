// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:dash_mobile/firebase_options.dart';
import 'package:dash_mobile/presentation/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class TestFirebaseApp extends FirebaseAppPlatform {
  TestFirebaseApp(super.name, super.options);
}

class TestFirebasePlatform extends FirebasePlatform {
  final List<FirebaseAppPlatform> _apps = <FirebaseAppPlatform>[];

  @override
  List<FirebaseAppPlatform> get apps => _apps;

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return _apps.firstWhere((app) => app.name == name);
  }

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    final appName = name ?? defaultFirebaseAppName;
    final resolvedOptions = options ??
        const FirebaseOptions(
          apiKey: 'test',
          appId: 'test',
          messagingSenderId: 'test',
          projectId: 'test',
        );
    final app = TestFirebaseApp(appName, resolvedOptions);
    _apps.add(app);
    return app;
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    FirebasePlatform.instance = TestFirebasePlatform();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  testWidgets('App loads successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DashMobileApp());

    // Verify that the app loads without errors
    expect(find.byType(DashMobileApp), findsOneWidget);
  });
}
