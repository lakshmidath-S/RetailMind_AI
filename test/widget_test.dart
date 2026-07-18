import 'package:flutter_test/flutter_test.dart';
import 'package:retailmind_ai/main.dart';

void main() {
  testWidgets('opens the voice-first new bill screen', (WidgetTester tester) async {
    await tester.pumpWidget(const RetailMindApp());

    expect(find.text('New Bill'), findsOneWidget);
    await tester.tap(find.byKey(const Key('newBillButton')));
    await tester.pumpAndSettle();

    expect(find.text('Create a bill by voice'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('voice toggle changes the listening state', (WidgetTester tester) async {
    await tester.pumpWidget(const RetailMindApp());
    await tester.tap(find.byKey(const Key('newBillButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('voiceToggleButton')));
    await tester.pump();

    expect(find.text('Listening…'), findsOneWidget);
    expect(find.text('Stop recording'), findsOneWidget);
  });
}
