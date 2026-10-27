import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/domain/pip_structured_reply.dart';
import 'package:personal_assistant/widgets/pip_params.dart';

void main() {
  group('PipStructuredReply Unit Tests', () {
    test('parses pure JSON string correctly', () {
      const raw = '''
      {
        "text": "Hello there! I am ready to help you.",
        "emotion": "happy",
        "intensity": 0.8,
        "animation": "wave",
        "voice_style": "normal",
        "tool_call": {
          "name": "get_weather",
          "args": {"city": "London"}
        },
        "memory_candidates": ["User lives in London"]
      }
      ''';

      final reply = PipStructuredReply.parseRaw(raw);
      expect(reply.text, 'Hello there! I am ready to help you.');
      expect(reply.emotion, 'happy');
      expect(reply.intensity, 0.8);
      expect(reply.animation, 'wave');
      expect(reply.voiceStyle, 'normal');
      expect(reply.toolCallName, 'get_weather');
      expect(reply.toolCallArgs?['city'], 'London');
      expect(reply.memoryCandidates, contains('User lives in London'));
      expect(reply.toPipMood(), PipMood.happy);
    });

    test('parses fenced markdown block correctly', () {
      const raw = '''
      Here is your answer:
      ```json
      {
        "text": "Fenced output test.",
        "emotion": "happy",
        "intensity": 0.5,
        "animation": "idle",
        "voice_style": "normal"
      }
      ```
      Hope this helps!
      ''';

      final reply = PipStructuredReply.parseRaw(raw);
      expect(reply.text, 'Fenced output test.');
      expect(reply.emotion, 'happy');
      expect(reply.toPipMood(), PipMood.happy);
    });

    test('gracefully recovers from garbage or non-JSON text', () {
      const raw = 'Just a regular plain-text response without any JSON structures whatsoever.';
      final reply = PipStructuredReply.parseRaw(raw);
      expect(reply.text, raw);
      expect(reply.emotion, 'calm');
      expect(reply.toolCallName, isNull);
    });
  });
}
