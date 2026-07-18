import 'package:flutter_test/flutter_test.dart';
import 'package:retailmind_ai/main.dart';

void main() {
  testWidgets('opens the voice-first new bill screen', (tester) async {
    await tester.pumpWidget(const RetailMindApp());
    await tester.tap(find.byKey(const Key('newBillButton')));
    await tester.pumpAndSettle();

    expect(find.text('Create a bill by voice'), findsOneWidget);
    expect(find.text('Start recording'), findsOneWidget);
  });

  testWidgets('stopping recording opens the draft bill', (tester) async {
    await tester.pumpWidget(const RetailMindApp());
    await tester.tap(find.byKey(const Key('newBillButton')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('voiceToggleButton')));
    await tester.pump();
    expect(find.text('Listening...'), findsOneWidget);

    await tester.tap(find.byKey(const Key('voiceToggleButton')));
    await tester.pump();
    expect(find.text('Generating your bill...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Your bill is ready'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.byKey(const Key('editBillButton')), findsOneWidget);
  });

  testWidgets('correction controls appear only after choosing to correct', (tester) async {
    await tester.pumpWidget(const DraftBillScreen());

    expect(find.byKey(const Key('addItemButton')), findsNothing);
    await tester.tap(find.byKey(const Key('editBillButton')));
    await tester.pump();

    expect(find.byKey(const Key('addItemButton')), findsOneWidget);
    expect(find.byKey(const Key('proceedButton')), findsOneWidget);
  });
}
