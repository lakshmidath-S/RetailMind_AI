/// Normalizes raw Whisper transcription output into clean, parseable text.
///
/// Handles:
/// - Numeric word-to-digit conversion (English & Malayalam)
/// - Filler words removal ("um", "uh", "like", "please", etc.)
/// - Punctuation cleanup
/// - Common Whisper artifacts (hallucinated punctuation, repeated phrases)
/// - Malayalam transliteration normalization
class TranscriptNormalizer {
  /// Normalize a raw transcript string into clean segments.
  static String normalize(String raw) {
    var text = raw.toLowerCase().trim();

    // Remove common Whisper hallucination artifacts
    text = _removeHallucinations(text);

    // Remove filler words
    text = _removeFillers(text);

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    // Normalize punctuation — treat "and", "&", "+" as separators
    text = text.replaceAll(RegExp(r'\band\b'), ',');
    text = text.replaceAll('&', ',');
    text = text.replaceAll('+', ',');

    // Normalize sentence-ending punctuation to commas (for segment splitting)
    text = text.replaceAll('.', ',');
    text = text.replaceAll(';', ',');

    // Collapse multiple commas
    text = text.replaceAll(RegExp(r',\s*,+'), ',');

    // Remove leading/trailing commas
    text = text.replaceAll(RegExp(r'^\s*,\s*'), '');
    text = text.replaceAll(RegExp(r'\s*,\s*$'), '');

    // Convert numeric words to digits
    text = _wordsToDigits(text);

    return text.trim();
  }

  /// Split a normalized transcript into individual item segments.
  static List<String> splitSegments(String normalizedText) {
    // First, split by explicit separators (commas)
    final initialParts = normalizedText
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final result = <String>[];

    for (var part in initialParts) {
      // Auto-insert commas for continuous speech (e.g., "2 milk 1 bread")
      final startsWithDigit = RegExp(r'^\d').hasMatch(part);

      if (startsWithDigit) {
        // Pattern: Qty Product Qty Product (e.g., "2 milk 1 bread")
        // Split between Product (Letter) and Qty (Digit)
        part = part.replaceAllMapped(
            RegExp(r'(\p{L})\s+(\d+(?:\.\d+)?)', unicode: true), (m) {
          return '${m.group(1)}, ${m.group(2)}';
        });
      } else {
        // Pattern: Product Qty Product Qty (e.g., "milk 2 bread 1")
        // Split between Qty (Digit) and Product (Letter)
        part = part.replaceAllMapped(
            RegExp(r'(\d+(?:\.\d+)?)\s+(\p{L})', unicode: true), (m) {
          return '${m.group(1)}, ${m.group(2)}';
        });
      }

      // Add the auto-split parts
      result.addAll(part
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty));
    }

    return result;
  }

  static String _removeHallucinations(String text) {
    // Whisper sometimes outputs these artifacts
    const artifacts = [
      'thank you.',
      'thanks for watching.',
      'please subscribe.',
      'you',
      '[music]',
      '(music)',
      '[applause]',
      '♪',
    ];
    for (final artifact in artifacts) {
      text = text.replaceAll(artifact, '');
    }
    // Remove repeated phrases (Whisper hallucination pattern)
    // e.g., "two milk two milk" → "two milk"
    text = text.replaceAll(RegExp(r'\b(\w+(?:\s+\w+){1,3})\s+\1\b'), r'$1');
    return text;
  }

  static String _removeFillers(String text) {
    const fillers = [
      'um', 'uh', 'uhh', 'umm', 'hmm', 'hm',
      'like', 'you know', 'basically', 'actually',
      'please', 'i want', 'i need', 'give me', 'add',
      'put', 'i would like', 'can i get', 'can i have',
    ];
    for (final filler in fillers) {
      // Use word boundaries for short fillers, substring match for phrases
      if (filler.contains(' ')) {
        text = text.replaceAll(filler, '');
      } else {
        text = text.replaceAll(RegExp('\\b$filler\\b'), '');
      }
    }
    return text;
  }

  /// Converts number words to digits.
  /// "two milk" → "2 milk"
  /// "രണ്ട് പാൽ" → "2 പാൽ"
  static String _wordsToDigits(String text) {
    // English number words
    const english = <String, String>{
      'one': '1', 'a ': '1 ', 'an ': '1 ',
      'two': '2', 'three': '3', 'four': '4', 'five': '5',
      'six': '6', 'seven': '7', 'eight': '8', 'nine': '9', 'ten': '10',
      'eleven': '11', 'twelve': '12', 'thirteen': '13',
      'fourteen': '14', 'fifteen': '15', 'twenty': '20',
      'half': '0.5', 'quarter': '0.25',
      'dozen': '12', 'half dozen': '6',
    };

    // Malayalam number words
    const malayalam = <String, String>{
      'ഒരു': '1', 'ഒന്ന്': '1',
      'രണ്ട്': '2', 'രണ്ടു': '2',
      'മൂന്ന്': '3', 'മൂന്നു': '3',
      'നാല്': '4', 'നാലു': '4',
      'അഞ്ച്': '5', 'അഞ്ചു': '5',
      'ആറ്': '6', 'ആറു': '6',
      'ഏഴ്': '7', 'ഏഴു': '7',
      'എട്ട്': '8', 'എട്ടു': '8',
      'ഒൻപത്': '9', 'ഒൻപതു': '9',
      'പത്ത്': '10', 'പത്തു': '10',
    };

    // Hindi number words (common in Indian retail)
    const hindi = <String, String>{
      'ek': '1', 'do': '2', 'teen': '3', 'chaar': '4', 'paanch': '5',
      'che': '6', 'saat': '7', 'aath': '8', 'nau': '9', 'das': '10',
    };

    // Process longest matches first (e.g., "half dozen" before "half")
    final allMappings = <String, String>{
      ...english,
      ...malayalam,
      ...hindi,
    };

    // Sort by length (longest first) to avoid partial replacements
    final sortedKeys = allMappings.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedKeys) {
      final digit = allMappings[word]!;
      // For very short words (like 'a'), only replace with word boundary
      if (word.length <= 2 && !word.contains(' ')) {
        text = text.replaceAll(RegExp('\\b$word\\b'), digit);
      } else {
        text = text.replaceAll(word, digit);
      }
    }

    return text;
  }
}
