import 'dart:math' as math;
import 'dart:typed_data';

enum VadEvent { none, speechStarted, speechEnded, noSpeechTimeout }

/// Decides when someone starts and stops talking from 16-bit PCM frames.
///
/// Adapts to the room: the noise floor tracks the quietest recent level, and
/// speech must rise [startMarginDb] above it. Short blips (a cough, a door)
/// shorter than [minSpeech] are ignored; speech ends after [endSilence] of
/// quiet. Pure Dart, so it is unit-tested without a microphone.
class VoiceActivityDetector {
  final double startMarginDb;
  final double endMarginDb;
  final Duration minSpeech;
  final Duration endSilence;
  final Duration noSpeechTimeout;

  VoiceActivityDetector({
    this.startMarginDb = 12,
    this.endMarginDb = 7,
    this.minSpeech = const Duration(milliseconds: 250),
    // Long enough for a thinking pause mid-sentence, short enough to feel quick.
    this.endSilence = const Duration(milliseconds: 1200),
    this.noSpeechTimeout = const Duration(seconds: 6),
  });

  /// How long to measure the room before deciding anything.
  static const Duration calibration = Duration(milliseconds: 300);

  double _noiseFloorDb = -55;
  bool _calibrated = false;
  Duration _elapsed = Duration.zero;
  Duration _loudFor = Duration.zero;
  Duration _quietFor = Duration.zero;
  bool _speaking = false;
  bool _done = false;

  bool get isSpeaking => _speaking;
  double get noiseFloorDb => _noiseFloorDb;

  /// Level of the last frame, 0..1, for a mic meter.
  double level = 0;

  /// Feeds one frame of little-endian 16-bit mono PCM at [sampleRate].
  VadEvent addFrame(Uint8List pcm, {int sampleRate = 16000}) {
    if (_done || pcm.length < 2) return VadEvent.none;
    final samples = pcm.length ~/ 2;
    final frame = Duration(microseconds: samples * 1000000 ~/ sampleRate);
    _elapsed += frame;
    final db = levelDb(pcm);
    level = ((db + 60) / 60).clamp(0.0, 1.0);

    // First, just listen to the room. The floor is the quietest moment, not
    // the average, so a beep or an early word can't make Pip think the room
    // is loud (and then miss normal speech).
    if (_elapsed <= calibration) {
      _noiseFloorDb = _calibrated ? math.min(_noiseFloorDb, db) : db;
      _calibrated = true;
      return VadEvent.none;
    }

    // Then the floor drifts down quickly and up slowly, so speech doesn't raise it.
    if (!_speaking) {
      _noiseFloorDb = db < _noiseFloorDb ? db : _noiseFloorDb + (db - _noiseFloorDb) * .02;
    }

    if (!_speaking) {
      _loudFor = db > _noiseFloorDb + startMarginDb ? _loudFor + frame : Duration.zero;
      if (_loudFor >= minSpeech) {
        _speaking = true;
        _quietFor = Duration.zero;
        return VadEvent.speechStarted;
      }
      if (_elapsed >= noSpeechTimeout) {
        _done = true;
        return VadEvent.noSpeechTimeout;
      }
      return VadEvent.none;
    }

    _quietFor = db < _noiseFloorDb + endMarginDb ? _quietFor + frame : Duration.zero;
    if (_quietFor >= endSilence) {
      _done = true;
      return VadEvent.speechEnded;
    }
    return VadEvent.none;
  }

  /// RMS level of a 16-bit PCM frame in dBFS (-96 … 0).
  static double levelDb(Uint8List pcm) {
    final data = ByteData.sublistView(pcm);
    final n = pcm.length ~/ 2;
    if (n == 0) return -96;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768;
      sum += s * s;
    }
    final rms = math.sqrt(sum / n);
    return rms <= 0 ? -96 : math.max(-96, 20 * math.log(rms) / math.ln10);
  }
}

/// Wraps raw 16-bit mono PCM in a WAV header so it can be sent as audio/wav.
Uint8List pcmToWav(Uint8List pcm, {int sampleRate = 16000}) {
  final header = ByteData(44);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  header.setUint32(4, 36 + pcm.length, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM chunk size
  header.setUint16(20, 1, Endian.little); // PCM format
  header.setUint16(22, 1, Endian.little); // mono
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  header.setUint16(32, 2, Endian.little); // block align
  header.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  header.setUint32(40, pcm.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...pcm]);
}
