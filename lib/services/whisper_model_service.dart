import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WhisperModelService {
  static const String assetPath = 'assets/models/ggml-tiny.bin';
  static const String targetName = 'ggml-tiny.bin'; // whisper_ggml expects this exact name

  static Future<String> getModelPath() async {
    // whisper_ggml looks in getApplicationSupportDirectory on Android
    final supportDir = await getApplicationSupportDirectory();
    final modelFile = File(p.join(supportDir.path, targetName));

    if (!await modelFile.exists()) {
      print('Model not found locally. Copying from assets to ${modelFile.path}...');
      try {
        final byteData = await rootBundle.load(assetPath);
        final buffer = byteData.buffer;
        await modelFile.writeAsBytes(
            buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        print('Model copied successfully to ${modelFile.path}');
      } catch (e) {
        print('Error copying model: $e');
        rethrow;
      }
    } else {
      print('Model already exists at ${modelFile.path}');
    }

    return modelFile.path;
  }
}
