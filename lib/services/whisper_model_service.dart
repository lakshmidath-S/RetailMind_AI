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
  // ── English & Malayalam model (Medium Q5) ──
  static const String _q5AssetPath = 'assets/models/ggml-model-q5_0.bin';
  static const String _mediumFileName = 'ggml-medium.bin'; // whisper_ggml expects this name for WhisperModel.medium

  /// Returns the path to the appropriate model for the given language.
  /// Copies from assets to local storage if not already present.
  static Future<String> getModelPath(VoiceLanguage language) async {
    // The user requested to use the Q5 model everywhere
    const assetPath = _q5AssetPath;
    const fileName = _mediumFileName;

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
