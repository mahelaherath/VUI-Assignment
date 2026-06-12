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
}
