// Basic Flutter widget test for Operon Client Web.
// Uses DashWebApp and verifies the app builds and settles.

import 'package:flutter_test/flutter_test.dart';

import 'package:dash_web/presentation/app.dart';

void main() {
  testWidgets('DashWebApp builds and settles', (WidgetTester tester) async {
    await tester.pumpWidget(const DashWebApp());
    await tester.pumpAndSettle();
    expect(find.byType(DashWebApp), findsOneWidget);
  });
}
