import 'package:flutter/foundation.dart';
import '../domain/speech_transcriber.dart';
import 'utterance_recorder.dart';

/// "Accurate" listening: record one utterance with voice detection, then
/// transcribe it (Gemini audio). Null result means nobody spoke.
class GeminiVoiceCapture {
  final UtteranceRecorder recorder;
  final SpeechTranscriber transcriber;

  GeminiVoiceCapture({required this.recorder, required this.transcriber});

  /// Mic level 0..1 while recording.
  ValueListenable<double> get level => recorder.level;

  bool get isRecording => recorder.isRecording;

  /// [followUp] waits less for speech to start (Pip just asked something).
  /// [alwaysOn] waits indefinitely (open-mic mode).
  Future<TranscriptResult?> listenOnce({bool followUp = false, bool alwaysOn = false}) async {
    final wav = await recorder.capture(
      noSpeechTimeout: alwaysOn ? null : Duration(seconds: followUp ? 5 : 8),
    );
    if (wav == null) return null;
    return transcriber.transcribe(wav);
  }

  Future<void> stop() => recorder.stop();
}
