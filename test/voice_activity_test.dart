import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/voice/domain/voice_activity_detector.dart';

/// 20 ms of a sine at [amplitude] (0..1) as 16-bit PCM, 16 kHz.
Uint8List tone(double amplitude, {int ms = 20}) {
  final n = 16 * ms;
  final b = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    b.setInt16(i * 2, (math.sin(i * .2) * amplitude * 32767).round(), Endian.little);
  }
  return b.buffer.asUint8List();
}

List<VadEvent> feed(VoiceActivityDetector vad, double amplitude, int frames) =>
    [for (var i = 0; i < frames; i++) vad.addFrame(tone(amplitude))];

void main() {
  test('levels: silence is very low, a loud tone is near 0 dBFS', () {
    expect(VoiceActivityDetector.levelDb(tone(0)), -96);
    expect(VoiceActivityDetector.levelDb(tone(.9)), greaterThan(-4));
  });

  test('detects speech after room noise, then its end after silence', () {
    final vad = VoiceActivityDetector();
    expect(feed(vad, .002, 25), everyElement(VadEvent.none)); // quiet room, 0.5 s
    final started = feed(vad, .3, 20);
    expect(started, contains(VadEvent.speechStarted));
    expect(vad.isSpeaking, isTrue);
    final ended = feed(vad, .002, 60); // 1.2 s of quiet
    expect(ended, contains(VadEvent.speechEnded));
  });

  test('a short blip (cough) does not count as speech', () {
    final vad = VoiceActivityDetector();
    feed(vad, .002, 25);
    expect(feed(vad, .4, 5), everyElement(VadEvent.none)); // 100 ms < 250 ms
    expect(vad.isSpeaking, isFalse);
  });

  test('gives up when nobody speaks', () {
    final vad = VoiceActivityDetector(noSpeechTimeout: const Duration(seconds: 1));
    expect(feed(vad, .002, 60), contains(VadEvent.noSpeechTimeout));
  });

  test('a steady noisy room raises the floor so it is not mistaken for speech', () {
    final vad = VoiceActivityDetector();
    expect(feed(vad, .02, 100), isNot(contains(VadEvent.speechStarted)));
  });

  test('WAV header describes 16 kHz mono 16-bit PCM', () {
    final wav = pcmToWav(Uint8List(3200));
    final b = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(b.getUint32(24, Endian.little), 16000);
    expect(b.getUint16(34, Endian.little), 16);
    expect(b.getUint32(40, Endian.little), 3200);
    expect(wav.length, 3244);
  });
}
