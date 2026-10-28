import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:personal_assistant/core/services/wake_word.dart';
import 'package:personal_assistant/features/voice/data/gemini_audio_transcriber.dart';
import 'package:personal_assistant/features/voice/data/voice_settings.dart';
import 'package:personal_assistant/features/voice/domain/speech_transcriber.dart';
import 'package:shared_preferences/shared_preferences.dart';

GeminiAudioTranscriber transcriber(MockClientHandler handler, {String key = 'k'}) =>
    GeminiAudioTranscriber(apiKey: () => key, model: () => 'gemini-3.8-flash', client: MockClient(handler));

void main() {
  group('Gemini audio transcriber', () {
    test('sends the audio inline to the chosen model and returns the transcript', () async {
      late Map<String, dynamic> sent;
      late Uri url;
      final t = transcriber((req) async {
        url = req.url;
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Remind me to call mum at 7. '}
                    ]
                  }
                }
              ]
            }),
            200);
      });
      final r = await t.transcribe(Uint8List.fromList([1, 2, 3]));
      expect(r, const TranscriptResult.success('Remind me to call mum at 7.'));
      expect(url.path, contains('gemini-3.8-flash:generateContent'));
      final parts = sent['contents'][0]['parts'] as List;
      expect(parts[1]['inline_data']['mime_type'], 'audio/wav');
      expect(parts[1]['inline_data']['data'], base64Encode([1, 2, 3]));
    });

    test('quota errors come back in plain words, not JSON', () async {
      final r = await transcriber((_) async => http.Response('{"error":{"code":429,"message":"quota"}}', 429))
          .transcribe(Uint8List(4));
      expect(r.isSuccess, isFalse);
      expect(r.error, contains('usage limit'));
    });

    test('no key means a clear setup hint, without calling the network', () async {
      var called = false;
      final r = await transcriber((_) async {
        called = true;
        return http.Response('', 200);
      }, key: '')
          .transcribe(Uint8List(4));
      expect(called, isFalse);
      expect(r.error, contains('Gemini key'));
    });
  });

  group('Wake word', () {
    test('recognises Pip and its common mishearings', () {
      expect(WakeWord.matches('hey pip what time is it'), isTrue);
      expect(WakeWord.matches('Peep, set an alarm'), isTrue);
      expect(WakeWord.matches('okay bip'), isTrue);
      expect(WakeWord.matches('what time is it'), isFalse);
    });

    test('strips the wake word to leave the command', () {
      expect(WakeWord.followUp('Hey Pip, set a timer'), 'set a timer');
      expect(WakeWord.followUp('pip what is the weather'), 'what is the weather');
    });
  });

  test('voice settings persist and default sensibly', () async {
    SharedPreferences.setMockInitialValues({});
    final s = VoiceSettings.instance;
    await s.load();
    expect(s.engine, SpeechEngine.onDevice);
    expect(s.conversationMode, isTrue);
    expect(s.handsFree, isFalse);
    await s.update(engine: SpeechEngine.geminiAudio, openMic: true);
    await s.load();
    expect(s.engine, SpeechEngine.geminiAudio);
    expect(s.openMic, isTrue);
    expect(s.handsFree, isTrue);
  });
}
