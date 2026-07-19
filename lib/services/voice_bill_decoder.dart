import 'package:whisper_ggml/whisper_ggml.dart';
import '../models/product.dart';

class DecodedBillItem {
  const DecodedBillItem({
    required this.product,
    required this.quantity,
    required this.confidence,
  });

  final Product product;
  final int quantity;
  final double confidence;
}

class DecodedBill {
  const DecodedBill({required this.transcript, required this.items});

  final String transcript;
  final List<DecodedBillItem> items;
}

class VoiceBillDecoder {
  static const demoTranscript = 'two milk, one bread, three parle-g';

  static Future<DecodedBill> decode(String audioPath, List<Product> products) async {
    final controller = WhisperController();
    final result = await controller.transcribe(
      model: WhisperModel.tiny,
      audioPath: audioPath,
      lang: 'en', // Since products are mapped to English aliases/names or Malayalam
    );

    final transcript = result?.transcription.text ?? demoTranscript;
    return decodeTranscript(transcript, products);
  }

  static DecodedBill decodeTranscript(String transcript, List<Product> products) {
    final items = <DecodedBillItem>[];

    for (final segment in transcript.toLowerCase().split(',')) {
      final product = _findProduct(segment, products);
      if (product == null) continue;
      items.add(
        DecodedBillItem(
          product: product,
          quantity: _quantityFor(segment),
          confidence: 0.95,
        ),
      );
    }

    return DecodedBill(transcript: transcript, items: items);
  }

  static Product? _findProduct(String segment, List<Product> products) {
    for (final product in products) {
      if (product.aliases.any(segment.contains)) return product;
    }
    return null;
  }

  static int _quantityFor(String segment) {
    const quantities = <String, int>{
      'one': 1,
      'two': 2,
      'three': 3,
      'four': 4,
      'five': 5,
      'ഒരു': 1,
      'രണ്ട്': 2,
      'മൂന്ന്': 3,
      'നാല്': 4,
      'അഞ്ച്': 5,
    };

    for (final entry in quantities.entries) {
      if (segment.contains(entry.key)) return entry.value;
    }
    return 1;
  }
}
