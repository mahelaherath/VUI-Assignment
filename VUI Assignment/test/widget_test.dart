import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vui_mental_health/main.dart';
import 'mock_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    setupMockChannels();
  });

  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SeraApp());

    // Verify that our app builds and shows the main title/brand name.
    expect(find.text('Sera'), findsWidgets);

    // Dispose the widget tree explicitly within the test body to trigger VuiStateManager.dispose
    await tester.pumpWidget(const SizedBox.shrink());

    // Allow the 2-second speech_to_text stop timer to fire and complete
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Sleep Hygiene interactive settings test', (WidgetTester tester) async {
    await tester.pumpWidget(const SeraApp());

    // Navigate to Sleep tab by tapping the "Sleep" label
    await tester.tap(find.text('Sleep'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify we are on the sleep screen
    expect(find.text('Sleep hygiene'), findsOneWidget);

    // Verify "Last night" stats card text is present
    final lastNightFinder = find.text('Last night');
    expect(lastNightFinder, findsOneWidget);

    // Ensure the "Last night" text is scrolled into view to avoid hit test issues
    await tester.ensureVisible(lastNightFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Tap "Last night" stats card to open the sleep duration dialog
    await tester.tap(lastNightFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify the Sleep Duration Dialog has opened
    expect(find.text('Log Sleep Time'), findsOneWidget);

    // Tap Save button to close dialog
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify dialog is closed
    expect(find.text('Log Sleep Time'), findsNothing);

    // Explicitly unmount to avoid pending timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
