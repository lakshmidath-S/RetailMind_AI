import 'package:whisper_ggml/whisper_ggml.dart';
import '../models/product.dart';
import 'transcript_normalizer.dart';
import 'quantity_parser.dart';
import 'matching_engine.dart';

class DecodedBillItem {
  const DecodedBillItem({
    required this.product,
    required this.quantity,
    required this.confidence,
    this.matchStrategy = MatchStrategy.none,
    this.matchedTerm = '',
  });

  final Product product;
  final int quantity;
  final double confidence;
  final MatchStrategy matchStrategy;
  final String matchedTerm;
}

class DecodedBill {
  const DecodedBill({
    required this.transcript,
    required this.items,
    this.unmatchedSegments = const [],
  });

  final String transcript;
  final List<DecodedBillItem> items;
  final List<String> unmatchedSegments;
}

class VoiceBillDecoder {


  /// Full pipeline: audio → Whisper transcription → normalizer → parser → matcher.
  static Future<DecodedBill> decode(String audioPath, List<Product> products) async {
    final controller = WhisperController();
    final result = await controller.transcribe(
      model: WhisperModel.tiny,
      audioPath: audioPath,
      lang: 'en',
    );

    final transcript = result?.transcription.text.trim();
    
    if (transcript == null) {
      throw Exception('Transcription failed. Ensure the audio is valid and model is loaded.');
    }
    
    if (transcript.isEmpty) {
      return DecodedBill(
        transcript: '',
        items: [],
        unmatchedSegments: ['No speech detected.'],
      );
    }
    
    return decodeTranscript(transcript, products);
  }

  /// Decode from a raw transcript string (used by tests and direct input).
  /// Now uses the full intelligence pipeline:
  ///   Normalize → Split → Parse quantities → Match products
  static DecodedBill decodeTranscript(String transcript, List<Product> products) {
    // Step 1: Normalize
    final normalized = TranscriptNormalizer.normalize(transcript);

    // Step 2: Split into segments
    final segments = TranscriptNormalizer.splitSegments(normalized);

    // Step 3: Parse quantities from each segment
    final parsedItems = QuantityParser.parseAll(segments);

    // Step 4: Match each parsed item to a product
    final engine = MatchingEngine(products);
    final items = <DecodedBillItem>[];
    final unmatched = <String>[];

    for (final parsed in parsedItems) {
      final match = engine.matchItem(parsed);
      if (match != null) {
        items.add(DecodedBillItem(
          product: match.product,
          quantity: parsed.wholeQuantity,
          confidence: match.confidence,
          matchStrategy: match.strategy,
          matchedTerm: match.matchedTerm,
        ));
      } else {
        unmatched.add(parsed.rawSegment);
      }
    }

    return DecodedBill(
      transcript: transcript,
      items: items,
      unmatchedSegments: unmatched,
    );
  }
}
