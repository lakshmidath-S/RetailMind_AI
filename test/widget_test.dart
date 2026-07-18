import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:retailmind_ai/main.dart';

import 'package:retailmind_ai/data/product_catalog.dart';
import 'package:retailmind_ai/services/voice_bill_decoder.dart';

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
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Generating your bill...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Your bill is ready'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.byKey(const Key('editBillButton')), findsOneWidget);
  });

  testWidgets('correction controls appear only after choosing to correct', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DraftBillScreen()));

    expect(find.byKey(const Key('addItemButton')), findsNothing);
    await tester.tap(find.byKey(const Key('editBillButton')));
    await tester.pump();

    expect(find.byKey(const Key('addItemButton')), findsOneWidget);
    expect(find.byKey(const Key('proceedButton')), findsOneWidget);
  });

  test('decodes several English bill items against the product catalogue', () {
    final bill = VoiceBillDecoder.decode(
      'two milk, one bread, three parle-g',
      productCatalog,
    );

    expect(bill.items, hasLength(3));
    expect(bill.items[0].product.name, 'Milk');
    expect(bill.items[0].quantity, 2);
    expect(bill.items[2].product.name, 'Parle-G');
    expect(bill.items[2].quantity, 3);
  });

  test('decodes Malayalam quantity and product aliases', () {
    final bill = VoiceBillDecoder.decode('രണ്ട് പാൽ, ഒരു ബ്രെഡ്', productCatalog);

    expect(bill.items, hasLength(2));
    expect(bill.items[0].quantity, 2);
    expect(bill.items[0].product.name, 'Milk');
    expect(bill.items[1].quantity, 1);
    expect(bill.items[1].product.name, 'Bread');
  });
}
