import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:retailmind_ai/main.dart';

import 'package:retailmind_ai/data/product_catalog.dart';
import 'package:retailmind_ai/services/voice_bill_decoder.dart';
import 'package:retailmind_ai/services/transcript_normalizer.dart';
import 'package:retailmind_ai/services/quantity_parser.dart';
import 'package:retailmind_ai/services/matching_engine.dart';

void main() {
  // Commented out: requires Supabase native initialization (AuthGate).
  // testWidgets('opens the voice-first new bill screen', (tester) async {
  //   await tester.pumpWidget(const RetailMindApp());
  //   await tester.tap(find.byKey(const Key('newBillButton')));
  //   await tester.pumpAndSettle();
  //
  //   expect(find.text('Create a bill by voice'), findsOneWidget);
  //   expect(find.text('Start recording'), findsOneWidget);
  // });

  // Commented out: requires native recording permissions/plugins.
  // testWidgets('stopping recording opens the draft bill', (tester) async {
  //   ...
  // });

  testWidgets('correction controls appear only after choosing to correct', (tester) async {
    await tester.pumpWidget(MaterialApp(home: DraftBillScreen()));

    expect(find.byKey(const Key('addItemButton')), findsNothing);
    await tester.tap(find.byKey(const Key('editBillButton')));
    await tester.pump();

    expect(find.byKey(const Key('addItemButton')), findsOneWidget);
    expect(find.byKey(const Key('proceedButton')), findsOneWidget);
  });

  // ────────────────── Transcript Normalizer Tests ──────────────────

  group('TranscriptNormalizer', () {
    test('converts number words to digits', () {
      final result = TranscriptNormalizer.normalize('two milk and three bread');
      expect(result, contains('2'));
      expect(result, contains('3'));
      expect(result, contains('milk'));
      expect(result, contains('bread'));
    });

    test('removes filler words', () {
      final result = TranscriptNormalizer.normalize('um give me two milk please');
      expect(result, isNot(contains('um')));
      expect(result, isNot(contains('please')));
      expect(result, contains('2'));
      expect(result, contains('milk'));
    });

    test('normalizes "and" to comma separator', () {
      final segments = TranscriptNormalizer.splitSegments(
        TranscriptNormalizer.normalize('milk and bread and coke'),
      );
      expect(segments.length, greaterThanOrEqualTo(3));
    });

    test('handles Malayalam number words', () {
      final result = TranscriptNormalizer.normalize('രണ്ട് പാൽ');
      expect(result, contains('2'));
      expect(result, contains('പാൽ'));
    });

    test('removes Whisper hallucination artifacts', () {
      final result = TranscriptNormalizer.normalize('two milk thank you. please subscribe.');
      expect(result, isNot(contains('thank you')));
      expect(result, isNot(contains('subscribe')));
    });
  });

  // ────────────────── Quantity Parser Tests ──────────────────

  group('QuantityParser', () {
    test('parses leading quantity', () {
      final item = QuantityParser.parse('2 milk');
      expect(item.quantity, 2);
      expect(item.productText, 'milk');
    });

    test('parses trailing quantity', () {
      final item = QuantityParser.parse('milk 3');
      expect(item.quantity, 3);
      expect(item.productText, 'milk');
    });

    test('defaults to quantity 1 when no number', () {
      final item = QuantityParser.parse('bread');
      expect(item.quantity, 1);
      expect(item.productText, 'bread');
    });

    test('handles NxProduct pattern', () {
      final item = QuantityParser.parse('2x maggi');
      expect(item.quantity, 2);
      expect(item.productText, 'maggi');
    });
  });

  // ────────────────── Matching Engine Tests ──────────────────

  group('MatchingEngine', () {
    final engine = MatchingEngine(productCatalog);

    test('exact match on product name', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'milk', quantity: 1, productText: 'milk',
      ));
      expect(result, isNotNull);
      expect(result!.product.name, 'Milk');
      expect(result.strategy, MatchStrategy.exact);
      expect(result.confidence, 1.0);
    });

    test('exact match on Malayalam name', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'പാൽ', quantity: 1, productText: 'പാൽ',
      ));
      expect(result, isNotNull);
      expect(result!.product.name, 'Milk');
      expect(result.confidence, 1.0);
    });

    test('alias containment match', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'glucose biscuit', quantity: 1, productText: 'glucose biscuit',
      ));
      expect(result, isNotNull);
      expect(result!.product.name, 'Parle-G');
      expect(result.strategy, MatchStrategy.alias);
    });

    test('fuzzy match on misspelled product', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'bred', quantity: 1, productText: 'bred',
      ));
      expect(result, isNotNull);
      expect(result!.product.name, 'Bread');
      expect(result.strategy, MatchStrategy.fuzzy);
    });

    test('phonetic match on sound-alike', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'soep', quantity: 1, productText: 'soep',
      ));
      // Should match "Soap" via phonetic similarity (S100 soundex)
      expect(result, isNotNull);
      expect(result!.product.name, 'Soap');
    });

    test('returns null for completely unknown product', () {
      final result = engine.matchItem(const ParsedItem(
        rawSegment: 'xyzqwerty', quantity: 1, productText: 'xyzqwerty',
      ));
      expect(result, isNull);
    });
  });

  // ────────────────── Full Pipeline (VoiceBillDecoder) Tests ──────────────────

  group('VoiceBillDecoder', () {
    test('decodes English bill items via matching engine', () {
      final bill = VoiceBillDecoder.decodeTranscript(
        'two milk, one bread, three parle-g',
        productCatalog,
      );

      expect(bill.items, hasLength(3));
      expect(bill.items[0].product.name, 'Milk');
      expect(bill.items[0].quantity, 2);
      expect(bill.items[1].product.name, 'Bread');
      expect(bill.items[1].quantity, 1);
      expect(bill.items[2].product.name, 'Parle-G');
      expect(bill.items[2].quantity, 3);
    });

    test('decodes Malayalam quantity and product aliases', () {
      final bill = VoiceBillDecoder.decodeTranscript('രണ്ട് പാൽ, ഒരു ബ്രെഡ്', productCatalog);

      expect(bill.items, hasLength(2));
      expect(bill.items[0].quantity, 2);
      expect(bill.items[0].product.name, 'Milk');
      expect(bill.items[1].quantity, 1);
      expect(bill.items[1].product.name, 'Bread');
    });

    test('handles natural speech with fillers', () {
      final bill = VoiceBillDecoder.decodeTranscript(
        'um give me two milk please, and one bread, and three maggi',
        productCatalog,
      );

      expect(bill.items.length, greaterThanOrEqualTo(3));
      final names = bill.items.map((i) => i.product.name).toList();
      expect(names, contains('Milk'));
      expect(names, contains('Bread'));
      expect(names, contains('Maggi'));
    });

    test('reports unmatched segments', () {
      final bill = VoiceBillDecoder.decodeTranscript(
        'two milk, one alienproduct123',
        productCatalog,
      );

      expect(bill.items, hasLength(1)); // milk matched
      expect(bill.unmatchedSegments, isNotEmpty); // alienproduct123 not matched
    });

    test('decodes brand names as aliases', () {
      final bill = VoiceBillDecoder.decodeTranscript(
        'one coke, two surf, one colgate',
        productCatalog,
      );

      expect(bill.items.length, greaterThanOrEqualTo(2));
      final names = bill.items.map((i) => i.product.name).toList();
      expect(names, contains('Coca-Cola'));
      expect(names, contains('Detergent'));
    });
  });
}
