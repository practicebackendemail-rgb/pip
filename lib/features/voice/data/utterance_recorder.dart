import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import '../domain/voice_activity_detector.dart';

/// Records one spoken utterance: opens the mic, waits for speech, keeps a
/// short pre-roll so the first syllable isn't clipped, and stops itself after
/// the speaker goes quiet. Returns WAV bytes, or null if nobody spoke.
class UtteranceRecorder {
  static const int sampleRate = 16000;
  static const Duration preRoll = Duration(milliseconds: 300);
  static const Duration maxLength = Duration(seconds: 20);

  final AudioRecorder _recorder;

  /// Mic level 0..1 while recording, for a live meter.
  final ValueNotifier<double> level = ValueNotifier(0);

  UtteranceRecorder({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  Completer<Uint8List?>? _active;
  StreamSubscription<Uint8List>? _sub;

  bool get isRecording => _active != null;

  /// Captures one utterance. [noSpeechTimeout] ends early if nobody talks
  /// (null waits indefinitely, for always-listening mode).
  Future<Uint8List?> capture({Duration? noSpeechTimeout = const Duration(seconds: 6)}) async {
    if (_active != null) return _active!.future;
    if (!await _recorder.hasPermission()) return null;

    final vad = VoiceActivityDetector(noSpeechTimeout: noSpeechTimeout ?? const Duration(days: 1));
    final done = _active = Completer<Uint8List?>();
    final preRollBytes = sampleRate * 2 * preRoll.inMilliseconds ~/ 1000;
    final maxBytes = sampleRate * 2 * maxLength.inSeconds;
    final pending = BytesBuilder(copy: false); // audio before speech starts (trimmed to pre-roll)
    final speech = BytesBuilder(copy: false);

    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
    ));

    _sub = stream.listen((chunk) {
      final event = vad.addFrame(chunk, sampleRate: sampleRate);
      level.value = vad.level;
      if (vad.isSpeaking || event == VadEvent.speechEnded) {
        speech.add(chunk);
      } else {
        pending.add(chunk);
        final bytes = pending.takeBytes();
        pending.add(bytes.length > preRollBytes ? bytes.sublist(bytes.length - preRollBytes) : bytes);
      }
      if (event == VadEvent.speechStarted) speech.add(pending.takeBytes());
      final tooLong = speech.length >= maxBytes;
      if (event == VadEvent.speechEnded || event == VadEvent.noSpeechTimeout || tooLong) {
        _finish(event == VadEvent.noSpeechTimeout ? null : speech.takeBytes());
      }
    }, onError: (Object e) {
      debugPrint('UtteranceRecorder stream error: $e');
      _finish(null);
    });
    return done.future;
  }

  /// Stops now; whatever was captured so far is returned by [capture].
  Future<void> stop() async => _finish(null);

  Future<void> _finish(Uint8List? pcm) async {
    final done = _active;
    if (done == null) return;
    _active = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    level.value = 0;
    done.complete(pcm == null || pcm.isEmpty ? null : pcmToWav(pcm, sampleRate: sampleRate));
  }

  Future<void> dispose() async {
    await _finish(null);
    level.dispose();
    await _recorder.dispose();
  }
}
