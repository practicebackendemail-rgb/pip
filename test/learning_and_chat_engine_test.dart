import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/embedding_tags.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';
import 'package:personal_assistant/core/services/embedding_backfill_service.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/core/services/task_provider.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_chat_engine.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_conversation_history.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_tool_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingEventLog implements EventLogService {
  final List<MapEntry<String, Map<String, dynamic>?>> logged = [];

  @override
  Future<void> log(String type, [Map<String, dynamic>? payload]) async => logged.add(MapEntry(type, payload));

  List<String> get types => logged.map((e) => e.key).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Replies with scripted texts in order and records every request.
class _ScriptedProvider implements LlmProvider {
  final List<String> replies;
  final List<List<LlmMessage>> requests = [];
  final List<Map<String, dynamic>?> schemas = [];
  _ScriptedProvider(this.replies);

  @override
  String get id => 'gemini';

  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsTools: true, supportsEmbeddings: true);

  @override
  Future<LlmResponse> chat(List<LlmMessage> messages, {List<ToolSpec>? tools, Map<String, dynamic>? jsonSchema}) async {
    requests.add(List.of(messages));
    schemas.add(jsonSchema);
    return LlmResponse(text: replies[requests.length - 1]);
  }

  @override
  Future<List<List<double>>> embed(List<String> texts) async => texts.map((t) => [t.length.toDouble(), 1.0]).toList();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _BackfillRepo implements MemoryRepository {
  final Map<String, MemoryItem> items;
  _BackfillRepo(List<MemoryItem> list) : items = {for (final m in list) m.id: m};

  @override
  Future<List<MemoryItem>> getMemoriesNeedingEmbedding(String embeddingModel, {int limit = 20}) async => items.values
      .where((m) => m.embedding == null || m.embeddingModel != embeddingModel)
      .take(limit)
      .toList();

  @override
  Future<void> updateMemoryEmbedding(String id, List<double> embedding, String embeddingModel) async {
    items[id] = items[id]!.copyWith(embedding: embedding, embeddingModel: embeddingModel);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _structured = '{"text":"Hi!","emotion":"happy","intensity":0.8,"animation":"wave","voice_style":"normal","memory_candidates":[]}';

PipChatEngine _engine() => PipChatEngine(
      toolCoordinator: PipToolCoordinator(toolRegistry: PipToolRegistry(), eventLog: _RecordingEventLog()),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'saved_tasks': '[]'}));

  group('Chat engine', () {
    test('plain-text answer with tools enabled gets one structured pass that restores emotion', () async {
      final provider = _ScriptedProvider(['Hello there', _structured]);
      final outcome = await _engine().run(
        provider: provider,
        systemContext: 'sys',
        userText: 'hi',
        toolSpecs: const [],
      );
      expect(provider.requests, hasLength(2));
      expect(provider.schemas.last, isNotNull);
      expect(outcome.reply!.emotion, 'happy');
    });

    test('structured answer needs no extra call', () async {
      final provider = _ScriptedProvider([_structured]);
      final outcome = await _engine().run(provider: provider, systemContext: 's', userText: 'hi', toolSpecs: const []);
      expect(provider.requests, hasLength(1));
      expect(outcome.reply!.text, 'Hi!');
    });

    test('previous turns are sent after the system prompt', () async {
      final engine = _engine();
      final provider = _ScriptedProvider([_structured, _structured]);
      await engine.run(provider: provider, systemContext: 's', userText: 'first');
      await engine.run(provider: provider, systemContext: 's', userText: 'second');
      final roles = provider.requests.last.map((m) => '${m.role}:${m.content}').toList();
      expect(roles, ['system:s', 'user:first', 'assistant:Hi!', 'user:second']);
    });
  });

  test('history keeps at most 8 turns and respects the size budget', () {
    final h = PipConversationHistory();
    for (var i = 0; i < 12; i++) {
      h.addTurn('q$i', 'a$i');
    }
    expect(h.messages, hasLength(16));
    expect(h.messages.first.content, 'q4');

    final small = PipConversationHistory(maxChars: 25);
    small.addTurn('x' * 10, 'y' * 10);
    small.addTurn('z' * 10, 'w' * 10);
    expect(small.messages.map((m) => m.content), ['z' * 10, 'w' * 10]);
  });

  test('backfill embeds untagged and other-model memories with the current tag', () async {
    final repo = _BackfillRepo([
      MemoryItem(id: 'a', text: 'no vector'),
      MemoryItem(id: 'b', text: 'old model', embedding: [1, 2, 3], embeddingModel: EmbeddingTags.openai),
      MemoryItem(id: 'c', text: 'current', embedding: [1, 1], embeddingModel: EmbeddingTags.gemini),
    ]);
    final service = EmbeddingBackfillService(memoryRepository: repo, embeddingProvider: () => _ScriptedProvider([]));
    expect(await service.run(), 2);
    expect(repo.items.values.every((m) => m.embeddingModel == EmbeddingTags.gemini), isTrue);
    expect(await service.run(), 0);
  });

  group('Task signals', () {
    Future<TaskProvider> loaded(_RecordingEventLog log, PipEmotionState emotion) async {
      final p = TaskProvider(eventLog: log, emotionState: emotion);
      await Future<void>.delayed(Duration.zero);
      return p;
    }

    test('create, uncomplete and delete are logged', () async {
      final log = _RecordingEventLog();
      final tasks = await loaded(log, PipEmotionState());
      tasks.addTask(title: 'Write report');
      final id = tasks.allTasks.first.id;
      tasks.toggleTask(id);
      tasks.toggleTask(id);
      tasks.deleteTask(id);
      expect(log.types, containsAllInOrder(['task_created', 'task_completed', 'task_uncompleted', 'task_deleted']));
      expect(jsonEncode(log.logged.first.value), isNot(contains('Write report')));
    });

    test('overdue penalty fires only when the overdue count grows', () async {
      final log = _RecordingEventLog();
      final emotion = PipEmotionState();
      final tasks = await loaded(log, emotion);
      final past = DateTime.now().subtract(const Duration(days: 2));
      for (var i = 0; i < 3; i++) {
        tasks.addTask(title: 'late $i', dueDate: past);
      }
      final before = emotion.valence;
      tasks.checkOverdueTasks();
      expect(emotion.valence, lessThan(before));

      final afterFirst = emotion.valence;
      tasks.checkOverdueTasks();
      expect(emotion.valence, afterFirst);
      expect(log.types.where((t) => t == 'tasks_overdue_accumulated'), hasLength(1));
    });
  });

  test('confirmed tool summary comes from the real result', () {
    expect(describeToolResult('send_email', {'status': 'sent', 'recipient': 'a@b.co'}), contains('a@b.co'));
    expect(
      describeToolResult('set_reminder', {'status': 'scheduled', 'scheduled_time': '2026-10-27T09:05:00.000'}),
      'Reminder set for 09:05.',
    );
  });
}
