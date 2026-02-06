import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vellum/main.dart';

void main() {
  testWidgets('Vellum app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: VellumApp()));

    // Verify that the app bar shows "Vellum"
    expect(find.text('Vellum'), findsOneWidget);
  });
}
