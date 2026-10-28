import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/core/services/tools/reminder_tool.dart';
import 'package:personal_assistant/core/services/tools/schedule_store.dart';
import 'package:personal_assistant/features/companion/domain/action_intent.dart';
import 'package:personal_assistant/features/companion/domain/day_briefing.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_chat_engine.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_tool_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Log implements EventLogService {
  @override
  Future<void> log(String type, [Map<String, dynamic>? payload]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Replies in order; the reply "CALL" becomes a native tool call.
class _Scripted implements LlmProvider {
  final List<String> replies;
  final List<List<LlmMessage>> requests = [];
  _Scripted(this.replies);

  @override
  String get id => 'gemini';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsTools: true);

  @override
  Future<LlmResponse> chat(List<LlmMessage> messages, {List<ToolSpec>? tools, Map<String, dynamic>? jsonSchema}) async {
    requests.add(List.of(messages));
    final r = replies[requests.length - 1];
    if (r == 'CALL') {
      return LlmResponse(text: '', toolCalls: [
        ToolCallRequest(id: 'c1', toolName: 'set_reminder', arguments: {'delay_seconds': 1200}),
      ]);
    }
    return LlmResponse(text: r);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PipChatEngine _engine() {
  final registry = PipToolRegistry()..registerTool(const ReminderTool());
  return PipChatEngine(toolCoordinator: PipToolCoordinator(toolRegistry: registry, eventLog: _Log()));
}

const _done = '{"text": "Twenty minutes it is!", "emotion": "happy"}';
const _setIt = '{"text": "Reminder set for 8:59 PM.", "emotion": "happy"}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Recognising requests to act', () {
    test('commands', () {
      for (final t in [
        'Remind me in 20 min',
        '(User is on the Alarms screen) remind me in 20 min',
        'wake me tomorrow at 7',
        'Please add milk to my list',
        'cancel the gym alarm',
        'can you set an alarm for 6?',
      ]) {
        expect(ActionIntent.isCommand(t), isTrue, reason: t);
      }
    });

    test('questions and chat', () {
      for (final t in ['What alarms do I have?', 'how are you', 'tell me a joke', "what's urgent?"]) {
        expect(ActionIntent.isCommand(t), isFalse, reason: t);
      }
    });
  });

  group('Pip never claims an action no tool did', () {
    test('a "done" without a tool call is pushed back once, then the tool runs', () async {
      final provider = _Scripted([_done, 'CALL', _setIt]);
      final outcome = await _engine().run(
        provider: provider,
        systemContext: 's',
        userText: 'Remind me in 20 min',
        toolSpecs: const [],
      );
      expect(provider.requests, hasLength(3));
      expect(provider.requests[1].last.content, PipChatEngine.actionNudge);
      expect(outcome.reply!.text, 'Reminder set for 8:59 PM.');
      expect((await ScheduleStore.all()).single.title, 'Reminder'); // it really exists
    });

    test('asking for a missing detail is fine, no push back', () async {
      final provider = _Scripted(['{"text": "Sure, what time?", "emotion": "calm"}']);
      await _engine().run(provider: provider, systemContext: 's', userText: 'set an alarm', toolSpecs: const []);
      expect(provider.requests, hasLength(1));
    });

    test('plain chat is answered in one call', () async {
      final provider = _Scripted(['{"text": "Hi!", "emotion": "happy"}']);
      await _engine().run(provider: provider, systemContext: 's', userText: 'hello', toolSpecs: const []);
      expect(provider.requests, hasLength(1));
    });
  });

  test('a reminder without a subject is still set', () async {
    final res = await const ReminderTool().execute({'delay_seconds': 1200});
    expect(res['status'], 'scheduled');
    expect(res['title'], 'Reminder');
  });

  test('inbox: repo tags are trimmed and automated senders get no Reply', () {
    final e = BriefEmail.parse('From: notifications@github.com | Subject: [practicebackendemail-rgb/pip] Run failed: CI');
    expect(e.subject, 'Run failed: CI');
    expect(e.canReply, isFalse);
    expect(BriefEmail.parse('From: priya@x.com | Subject: Deck?').canReply, isTrue);
  });
}
