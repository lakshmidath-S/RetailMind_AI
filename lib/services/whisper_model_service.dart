import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Supported voice input languages.
enum VoiceLanguage {
  english('en', 'English'),
  malayalam('ml', 'മലയാളം');

  const VoiceLanguage(this.code, this.displayName);
  final String code;
  final String displayName;
}

class WhisperModelService {
  // ── English model (base — fast, good for English) ──
  static const String _baseAssetPath = 'assets/models/ggml-base.bin';
  static const String _baseFileName = 'ggml-base.bin';

  // ── Malayalam model (small — better multilingual capacity) ──
  static const String _smallAssetPath = 'assets/models/ggml-small.bin';
  static const String _smallFileName = 'ggml-small.bin';

  /// Returns the path to the appropriate model for the given language.
  /// Copies from assets to local storage if not already present.
  static Future<String> getModelPath(VoiceLanguage language) async {
    final String assetPath;
    final String fileName;

    switch (language) {
      case VoiceLanguage.english:
        assetPath = _baseAssetPath;
        fileName = _baseFileName;
        break;
      case VoiceLanguage.malayalam:
        assetPath = _smallAssetPath;
        fileName = _smallFileName;
        break;
    }

    final supportDir = await getApplicationSupportDirectory();
    final modelFile = File(p.join(supportDir.path, fileName));

    if (!await modelFile.exists()) {
      print('[$fileName] Not found locally. Copying from assets to ${modelFile.path}...');
      try {
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer;
        await modelFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        print('[$fileName] Copied successfully to ${modelFile.path}');
      } catch (e) {
        print('[$fileName] Error copying model: $e');
        rethrow;
      }
    } else {
      print('[$fileName] Already exists at ${modelFile.path}');
    }

    return modelFile.path;
  }

  /// Pre-warm both models (copy from assets if needed).
  static Future<void> warmUp() async {
    await getModelPath(VoiceLanguage.english);
    // Only warm up Malayalam model if it exists in assets
    try {
      await getModelPath(VoiceLanguage.malayalam);
    } catch (_) {
      print('Malayalam model not bundled yet — will use package auto-download.');
    }
  }
}
