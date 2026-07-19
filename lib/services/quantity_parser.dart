

/// Represents a parsed item from a transcript segment.
/// Contains the raw text, extracted quantity, and the product name portion.
class ParsedItem {
  final String rawSegment;
  final double quantity;
  final String productText;

  const ParsedItem({
    required this.rawSegment,
    required this.quantity,
    required this.productText,
  });

  /// Whether the quantity is a whole number (for display purposes).
  int get wholeQuantity => quantity.round();

  @override
  String toString() => 'ParsedItem(qty: $quantity, product: "$productText")';
}

/// Extracts quantity and product text from a transcript segment.
///
/// Handles patterns like:
/// - "2 milk" → qty: 2, product: "milk"
/// - "milk 2" → qty: 2, product: "milk"  
/// - "milk" → qty: 1, product: "milk"
/// - "0.5 kg rice" → qty: 0.5, product: "kg rice"
class QuantityParser {

  /// Parse a single segment into a ParsedItem.
  static ParsedItem parse(String segment) {
    final trimmed = segment.trim();
    if (trimmed.isEmpty) {
      return const ParsedItem(rawSegment: '', quantity: 1, productText: '');
    }

    // Try to find a number at the start of the segment
    final leadingMatch = RegExp(r'^(\d+(?:\.\d+)?)\s+(.+)$').firstMatch(trimmed);
    if (leadingMatch != null) {
      final qty = double.tryParse(leadingMatch.group(1)!) ?? 1;
      return ParsedItem(
        rawSegment: trimmed,
        quantity: qty,
        productText: leadingMatch.group(2)!.trim(),
      );
    }

    // Try to find a number at the end of the segment
    final trailingMatch = RegExp(r'^(.+?)\s+(\d+(?:\.\d+)?)$').firstMatch(trimmed);
    if (trailingMatch != null) {
      final qty = double.tryParse(trailingMatch.group(2)!) ?? 1;
      return ParsedItem(
        rawSegment: trimmed,
        quantity: qty,
        productText: trailingMatch.group(1)!.trim(),
      );
    }

    // Try "NxProduct" pattern (e.g., "2x milk")
    final multiplyMatch = RegExp(r'^(\d+)\s*[xX×]\s*(.+)$').firstMatch(trimmed);
    if (multiplyMatch != null) {
      final qty = double.tryParse(multiplyMatch.group(1)!) ?? 1;
      return ParsedItem(
        rawSegment: trimmed,
        quantity: qty,
        productText: multiplyMatch.group(2)!.trim(),
      );
    }

    // No number found → default to qty 1
    return ParsedItem(
      rawSegment: trimmed,
      quantity: 1,
      productText: trimmed,
    );
  }

  /// Parse multiple segments at once.
  static List<ParsedItem> parseAll(List<String> segments) {
    return segments.map(parse).where((item) => item.productText.isNotEmpty).toList();
  }
}
