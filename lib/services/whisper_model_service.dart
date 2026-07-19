import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class WhisperModelService {
  static const String modelName = 'ggml-tiny.en.bin';
  static const String assetPath = 'assets/models/$modelName';

  static Future<String> getModelPath() async {
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = File(p.join(docDir.path, modelName));

    if (!await modelFile.exists()) {
      print('Model not found locally. Copying from assets...');
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
