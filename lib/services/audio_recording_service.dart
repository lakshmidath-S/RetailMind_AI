import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

class AudioRecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  // ─────────────────── WAV file recording (legacy) ───────────────────

  Future<void> startRecording() async {
    if (await hasPermission()) {
      final docDir = await getApplicationDocumentsDirectory();
      _currentRecordingPath = p.join(docDir.path, 'voice_bill_${DateTime.now().millisecondsSinceEpoch}.wav');
      
      // Whisper usually requires 16kHz, mono PCM 16-bit
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000, // Not strictly used for PCM but good to define
        ),
        path: _currentRecordingPath!,
      );
    } else {
      throw Exception('Microphone permission denied');
    }
  }

  Future<String?> stopRecording() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
      return _currentRecordingPath;
    }
    return null;
  }

  // ─────────────────── PCM stream for live transcription ───────────────────

  /// Starts recording as a raw PCM16 stream (16 kHz, mono).
  /// Returns the stream of audio bytes that can be fed directly
  /// to `WhisperController.transcribeLive(pcm16Stream: ...)`.
  Future<Stream<Uint8List>> startStream() async {
    if (!await hasPermission()) {
      throw Exception('Microphone permission denied');
    }
    final stream = await _audioRecorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    return stream;
  }

  /// Stops the current stream recording.
  Future<void> stopStream() async {
    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }
  }

  Future<bool> isRecording() async {
    return await _audioRecorder.isRecording();
  }

  void dispose() {
    _audioRecorder.dispose();
  }
}
