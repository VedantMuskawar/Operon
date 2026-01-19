import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operon_driver_android/presentation/views/driver_map_page.dart';

void main() {
  testWidgets('Map page renders placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DriverMapPage()));
    expect(find.text('Map (coming soon)'), findsOneWidget);
  });
}
