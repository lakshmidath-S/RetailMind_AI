import 'dart:math';
import '../models/product.dart';
import 'quantity_parser.dart';

/// The result of matching a parsed item to a product.
class MatchResult {
  final Product product;
  final double confidence;
  final MatchStrategy strategy;
  final String matchedTerm;

  const MatchResult({
    required this.product,
    required this.confidence,
    required this.strategy,
    required this.matchedTerm,
  });

  @override
  String toString() =>
      'MatchResult(${product.name}, confidence: ${(confidence * 100).toStringAsFixed(0)}%, '
      'strategy: ${strategy.name}, matched: "$matchedTerm")';
}

/// The strategy used to match a product.
enum MatchStrategy {
  exact,       // 1.0  — exact string match on name/alias
  alias,       // 0.95 — matched via alias list
  fuzzy,       // 0.6–0.85 — Levenshtein distance
  phonetic,    // 0.5–0.75 — Soundex/phonetic similarity
  none,        // 0.0  — no match found
}

/// Multi-strategy product matching engine.
///
/// Matching order (highest confidence first):
/// 1. **Exact match** — product name or alias is exactly the query
/// 2. **Alias match** — query contains or is contained by an alias
/// 3. **Fuzzy match** — Levenshtein distance within threshold
/// 4. **Phonetic match** — Soundex code similarity
///
/// Falls through to the next strategy if no match is found.
class MatchingEngine {
  final List<Product> _products;

  const MatchingEngine(this._products);

  /// Match a single parsed item to the best product.
  MatchResult? matchItem(ParsedItem item) {
    final query = item.productText.toLowerCase().trim();
    if (query.isEmpty) return null;

    // Strategy 1: Exact match
    final exact = _exactMatch(query);
    if (exact != null) return exact;

    // Strategy 2: Alias containment match
    final alias = _aliasMatch(query);
    if (alias != null) return alias;

    // Strategy 3: Fuzzy match (Levenshtein)
    final fuzzy = _fuzzyMatch(query);
    if (fuzzy != null) return fuzzy;

    // Strategy 4: Phonetic match (Soundex)
    final phonetic = _phoneticMatch(query);
    if (phonetic != null) return phonetic;

    return null;
  }

  /// Match all parsed items at once. Returns results in the same order.
  List<MatchResult?> matchAll(List<ParsedItem> items) {
    return items.map(matchItem).toList();
  }

  // ────────────────── Strategy 1: Exact Match ──────────────────

  MatchResult? _exactMatch(String query) {
    for (final product in _products) {
      // Check exact product name match
      if (product.name.toLowerCase() == query) {
        return MatchResult(
          product: product,
          confidence: 1.0,
          strategy: MatchStrategy.exact,
          matchedTerm: product.name,
        );
      }
      // Check exact alias match
      for (final alias in product.aliases) {
        if (alias.toLowerCase() == query) {
          return MatchResult(
            product: product,
            confidence: 1.0,
            strategy: MatchStrategy.exact,
            matchedTerm: alias,
          );
        }
      }
      // Check Malayalam name
      if (product.malayalamName.toLowerCase() == query) {
        return MatchResult(
          product: product,
          confidence: 1.0,
          strategy: MatchStrategy.exact,
          matchedTerm: product.malayalamName,
        );
      }
    }
    return null;
  }

  // ────────────────── Strategy 2: Alias Containment ──────────────────

  MatchResult? _aliasMatch(String query) {
    MatchResult? bestMatch;
    double bestScore = 0;

    for (final product in _products) {
      for (final alias in product.aliases) {
        final aliasLower = alias.toLowerCase();
        double score = 0;

        if (query.contains(aliasLower)) {
          // Query contains the alias — score based on how much of query is the alias
          score = aliasLower.length / query.length;
        } else if (aliasLower.contains(query)) {
          // Alias contains the query
          score = query.length / aliasLower.length;
        }

        if (score > 0.5 && score > bestScore) {
          bestScore = score;
          bestMatch = MatchResult(
            product: product,
            confidence: 0.85 + (score * 0.10), // 0.85–0.95
            strategy: MatchStrategy.alias,
            matchedTerm: alias,
          );
        }
      }

      // Also check brand + name combinations
      if (product.brand != null) {
        final brandName = '${product.brand} ${product.name}'.toLowerCase();
        if (query.contains(brandName) || brandName.contains(query)) {
          final score = min(query.length, brandName.length) /
              max(query.length, brandName.length);
          if (score > bestScore) {
            bestScore = score;
            bestMatch = MatchResult(
              product: product,
              confidence: 0.85 + (score * 0.10),
              strategy: MatchStrategy.alias,
              matchedTerm: brandName,
            );
          }
        }
      }
    }

    return bestMatch;
  }

  // ────────────────── Strategy 3: Fuzzy Match ──────────────────

  MatchResult? _fuzzyMatch(String query) {
    MatchResult? bestMatch;
    double bestScore = 0;

    for (final product in _products) {
      // Compare against product name
      final nameScore = _normalizedLevenshtein(query, product.name.toLowerCase());
      if (nameScore > bestScore) {
        bestScore = nameScore;
        bestMatch = MatchResult(
          product: product,
          confidence: 0.6 + (nameScore * 0.25), // 0.6–0.85
          strategy: MatchStrategy.fuzzy,
          matchedTerm: product.name,
        );
      }

      // Compare against each alias
      for (final alias in product.aliases) {
        final aliasScore = _normalizedLevenshtein(query, alias.toLowerCase());
        if (aliasScore > bestScore) {
          bestScore = aliasScore;
          bestMatch = MatchResult(
            product: product,
            confidence: 0.6 + (aliasScore * 0.25),
            strategy: MatchStrategy.fuzzy,
            matchedTerm: alias,
          );
        }
      }
    }

    // Only return fuzzy matches with a minimum similarity threshold
    if (bestScore >= 0.6) return bestMatch;
    return null;
  }

  // ────────────────── Strategy 4: Phonetic Match ──────────────────

  MatchResult? _phoneticMatch(String query) {
    // Only for ASCII/Latin text
    if (!RegExp(r'^[a-z\s\-]+$').hasMatch(query)) return null;

    final querySoundex = _soundex(query);
    if (querySoundex.isEmpty) return null;

    MatchResult? bestMatch;
    double bestScore = 0;

    for (final product in _products) {
      for (final alias in product.aliases) {
        if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(alias)) continue;

        final aliasSoundex = _soundex(alias.toLowerCase());
        if (aliasSoundex == querySoundex) {
          // Soundex match — use Levenshtein as a tiebreaker for confidence
          final levScore = _normalizedLevenshtein(query, alias.toLowerCase());
          final confidence = 0.5 + (levScore * 0.25); // 0.5–0.75

          if (confidence > bestScore) {
            bestScore = confidence;
            bestMatch = MatchResult(
              product: product,
              confidence: confidence,
              strategy: MatchStrategy.phonetic,
              matchedTerm: alias,
            );
          }
        }
      }
    }

    return bestMatch;
  }

  // ────────────────── Utility: Levenshtein Distance ──────────────────

  /// Returns a normalized similarity score (0.0–1.0) based on Levenshtein distance.
  /// 1.0 = identical, 0.0 = completely different.
  static double _normalizedLevenshtein(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final maxLen = max(s1.length, s2.length);
    final distance = _levenshteinDistance(s1, s2);
    return 1.0 - (distance / maxLen);
  }

  /// Compute raw Levenshtein edit distance between two strings.
  static int _levenshteinDistance(String s1, String s2) {
    final n = s1.length;
    final m = s2.length;

    // Use two rows instead of full matrix for memory efficiency
    var prev = List<int>.generate(m + 1, (i) => i);
    var curr = List<int>.filled(m + 1, 0);

    for (var i = 1; i <= n; i++) {
      curr[0] = i;
      for (var j = 1; j <= m; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,        // deletion
          curr[j - 1] + 1,    // insertion
          prev[j - 1] + cost, // substitution
        ].reduce(min);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[m];
  }

  // ────────────────── Utility: Soundex ──────────────────

  /// Standard American Soundex encoding.
  /// Returns empty string for non-Latin input.
  static String _soundex(String word) {
    final cleaned = word.replaceAll(RegExp(r'[^a-z]'), '');
    if (cleaned.isEmpty) return '';

    const codeMap = <String, String>{
      'b': '1', 'f': '1', 'p': '1', 'v': '1',
      'c': '2', 'g': '2', 'j': '2', 'k': '2', 'q': '2', 's': '2', 'x': '2', 'z': '2',
      'd': '3', 't': '3',
      'l': '4',
      'm': '5', 'n': '5',
      'r': '6',
    };

    final result = StringBuffer(cleaned[0].toUpperCase());
    var lastCode = codeMap[cleaned[0]] ?? '';

    for (var i = 1; i < cleaned.length && result.length < 4; i++) {
      final code = codeMap[cleaned[i]];
      if (code != null && code != lastCode) {
        result.write(code);
      }
      lastCode = code ?? '';
    }

    // Pad with zeros to length 4
    while (result.length < 4) {
      result.write('0');
    }

    return result.toString();
  }
}
