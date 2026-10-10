import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:negoo_super_admin/main.dart';

void main() {
  testWidgets('Admin Dashboard Layout & Navigation Test', (
    WidgetTester tester,
  ) async {
    // 1. Build our custom Admin app and trigger a frame.
    await tester.pumpWidget(const NegooCentralAdminApp());

    // Because the app initializes Supabase asynchronously in a FutureBuilder,
    // we need to tell the tester to wait until all animations and microtasks settle.
    await tester.pumpAndSettle();

    // 2. Verify that the Dashboard Title is present on screen
    expect(find.text('NEGOO HQ CONTROL'), findsOneWidget);

    // 3. Verify that the high-level platform section title exists
    expect(find.text('Platform Overview'), findsOneWidget);

    // 4. Verify that your bottom navigation items are rendered correctly
    expect(find.text('Metrics'), findsOneWidget);
    expect(find.text('Audits'), findsOneWidget);
    expect(find.text('Partners'), findsOneWidget);

    // 5. Test interaction: Tap on the 'Audits' tab in the bottom bar
    await tester.tap(find.byIcon(Icons.rate_review_outlined));

    // Trigger a frame redraw after the tap event to process the tab switch
    await tester.pumpAndSettle();

    // 6. Verify that the navigation successfully switched to the Document Validation Queue
    expect(find.text('Document Validation Queue'), findsOneWidget);
  });
}
