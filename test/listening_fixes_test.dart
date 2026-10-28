import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/voice/data/gemini_audio_transcriber.dart';
import 'package:personal_assistant/features/voice/domain/listen_delivery.dart';
import 'package:personal_assistant/features/voice/domain/voice_activity_detector.dart';

/// 20 ms of 16 kHz PCM: a tone at [amplitude] (0..1).
Uint8List frame(double amplitude) {
  final data = ByteData(320 * 2);
  for (var i = 0; i < 320; i++) {
    data.setInt16(i * 2, (sin(2 * pi * 440 * i / 16000) * amplitude * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

Future<void> afterGrace() => Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  group('Words Android heard are never thrown away', () {
    late List<String> heard;
    late int nothing;
    late ListenDelivery delivery;

    setUp(() {
      heard = [];
      nothing = 0;
      delivery = ListenDelivery(
        onHeard: heard.add,
        onNothing: () => nothing++,
        grace: const Duration(milliseconds: 10),
      );
    });

    test('stopped with only partial results: the partial words are used', () async {
      delivery
        ..begin()
        ..heard('remind me to call')
        ..heard('remind me to call mum at six')
        ..stopped();
      await afterGrace();
      expect(heard, ['remind me to call mum at six']);
    });

    test('a late final result wins, and is delivered once', () async {
      delivery
        ..begin()
        ..heard('set an alarm')
        ..stopped()
        ..heard('set an alarm for 7 am')
        ..deliver();
      await afterGrace();
      expect(heard, ['set an alarm for 7 am']);
    });

    test('nothing heard says so, instead of silently doing nothing', () async {
      delivery
        ..begin()
        ..stopped();
      await afterGrace();
      expect(heard, isEmpty);
      expect(nothing, 1);
    });

    test('a stop from the previous listen never fires into a new one', () async {
      delivery
        ..begin()
        ..heard('old words')
        ..stopped()
        ..begin(); // new listen before the grace period ends
      await afterGrace();
      expect(heard, isEmpty);
      expect(nothing, 0);
    });
  });

  group('Voice detector', () {
    test('a loud beep during calibration does not hide normal speech', () {
      final vad = VoiceActivityDetector();
      for (var i = 0; i < 5; i++) {
        vad.addFrame(frame(.6)); // 100 ms of beep
      }
      for (var i = 0; i < 10; i++) {
        vad.addFrame(frame(.002)); // then a quiet room
      }
      expect(vad.noiseFloorDb, lessThan(-50)); // the floor is the room, not the beep
      var started = false;
      for (var i = 0; i < 20 && !started; i++) {
        started = vad.addFrame(frame(.05)) == VadEvent.speechStarted; // normal speaking level
      }
      expect(started, isTrue);
    });

    test('a one-second thinking pause does not end your turn', () {
      final vad = VoiceActivityDetector();
      for (var i = 0; i < 15; i++) {
        vad.addFrame(frame(.002));
      }
      for (var i = 0; i < 20; i++) {
        vad.addFrame(frame(.1));
      }
      final pause = [for (var i = 0; i < 50; i++) vad.addFrame(frame(.002))]; // 1.0 s quiet
      expect(pause, isNot(contains(VadEvent.speechEnded)));
      expect([for (var i = 0; i < 15; i++) vad.addFrame(frame(.002))], contains(VadEvent.speechEnded));
    });
  });

  test('Gemini is told who is speaking, in what accent, and what to expect', () {
    final p = GeminiAudioTranscriber.promptFor(name: 'Akash', locale: 'en_IN');
    expect(p, contains('Akash'));
    expect(p, contains('en_IN'));
    expect(p, contains('"Pip"'));
    expect(GeminiAudioTranscriber.promptFor(), isNot(contains('language setting')));
  });
}
