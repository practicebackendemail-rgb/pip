import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/domain/pip_character_bible.dart';
import 'package:personal_assistant/features/companion/domain/pip_structured_reply.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_conversation_history.dart';

void main() {
  group('Odd replies never show raw JSON', () {
    test('a truncated JSON reply still shows its text and emotion', () {
      final r = PipStructuredReply.parseRaw('{"text": "Alarm set for 6:30 AM.", "emotion": "happy", "intens');
      expect(r.text, 'Alarm set for 6:30 AM.');
      expect(r.emotion, 'happy');
    });

    test('escaped quotes and line breaks in the text come out right', () {
      final r = PipStructuredReply.parseRaw(r'{"text": "She said \"hi\".\nDone", "emotion": "calm"');
      expect(r.text, 'She said "hi".\nDone');
    });

    test('plain prose keeps its words and uses a stray emotion tag', () {
      final r = PipStructuredReply.parseRaw('Ha, good one! [EMOTION: laughing]');
      expect(r.text, 'Ha, good one!');
      expect(r.emotion, 'laughing');
    });

    test('valid JSON is unchanged', () {
      final r = PipStructuredReply.parseRaw('{"text": "Hi", "emotion": "sad"}');
      expect(r.isStructured, isTrue);
      expect(r.emotion, 'sad');
    });
  });

  group('Prompt', () {
    String prompt({required bool native}) =>
        PipCharacterBible.buildSystemPrompt(emotionContext: '', nativeTools: native, toolsContext: native ? '' : 'Available Tools: x');

    test('explains when to use a task, a reminder or an alarm', () {
      final p = prompt(native: true);
      expect(p, contains('create_task'));
      expect(p, contains('set_reminder'));
      expect(p, contains('set_alarm'));
      expect(p, contains('ask one short question instead of guessing'));
    });

    test('with native tools, tool calls are never written as JSON text', () {
      final p = prompt(native: true);
      expect(p, isNot(contains('"tool_call"')));
      expect(p, contains('function calling'));
    });

    test('without native tools, the JSON carries the tool call', () {
      final p = prompt(native: false);
      expect(p, contains('"tool_call"'));
      expect(p, contains('Available Tools'));
    });
  });

  test('a confirmed action stays in the conversation for follow-ups', () {
    final h = PipConversationHistory()
      ..addTurn('cancel my gym alarm', "Cancel your 'gym' alarm or reminder?")
      ..addTurn('Yes, go ahead.', "Done, 'Gym' is cancelled. (cancel_reminder result: {\"status\":\"cancelled\"})");
    expect(h.messages.map((m) => m.content), contains(contains('cancel_reminder result')));
  });
}
