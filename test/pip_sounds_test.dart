import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/services/pip_sfx_service.dart';
import 'package:personal_assistant/features/companion/domain/pip_structured_reply.dart';
import 'package:personal_assistant/widgets/pip_params.dart';

void main() {
  test('every reply emotion has its own sound', () {
    expect(PipSfxService.forEmotion('laughing'), PipSound.laugh);
    expect(PipSfxService.forEmotion('sad'), PipSound.sad);
    expect(PipSfxService.forEmotion('sulky'), PipSound.sad);
    expect(PipSfxService.forEmotion('excited'), PipSound.excited);
    expect(PipSfxService.forEmotion('mischievous'), PipSound.excited);
    expect(PipSfxService.forEmotion('unsure'), PipSound.unsure);
    expect(PipSfxService.forEmotion('proud'), PipSound.happy);
    expect(PipSfxService.forEmotion('sleepy'), PipSound.sleep);
    expect(PipSfxService.forEmotion('calm'), PipSound.chirp);
  });

  test('laughing and sad replies show the matching face', () {
    PipMood mood(String e) => PipStructuredReply.parseRaw('{"text": "x", "emotion": "$e"}').toPipMood();
    expect(mood('laughing'), PipMood.laughing);
    expect(mood('sad'), PipMood.sad);
  });

  test('every sound file is a real WAV in the assets', () {
    for (final name in ['chirp', 'happy', 'thinking', 'blip', 'sleep', 'laugh', 'sad', 'excited', 'unsure', 'listen']) {
      final file = File('assets/audio/pip_$name.wav');
      expect(file.existsSync(), isTrue, reason: name);
      expect(String.fromCharCodes(file.readAsBytesSync().sublist(0, 4)), 'RIFF', reason: name);
    }
  });
}
