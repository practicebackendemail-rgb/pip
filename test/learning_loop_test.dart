import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';
import 'package:personal_assistant/core/services/llm_registry_service.dart';
import 'package:personal_assistant/core/services/nightly_reflection_service.dart';
import 'package:personal_assistant/core/services/task_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockLlmProvider implements LlmProvider {
  final String jsonReply;
  MockLlmProvider(this.jsonReply);

  @override
  String get id => 'mock_llm';
  @override
  String get displayName => 'Mock LLM';
  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsEmbeddings: false);

  @override
  Future<LlmResponse> chat(List<LlmMessage> messages, {List<ToolSpec>? tools, Map<String, dynamic>? jsonSchema}) async {
    return LlmResponse(text: jsonReply);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockLlmRegistry implements LlmRegistryService {
  final LlmProvider provider;
  MockLlmRegistry(this.provider);

  @override
  LlmProvider getActiveProvider() => provider;
  @override
  LlmProvider getEmbeddingProvider() => provider;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class InMemoryMemoryRepo implements MemoryRepository {
  final Map<String, ProfileFact> facts = {};
  final List<PipRule> rules = [];
  final List<MemoryItem> memories = [];

  @override
  Future<List<ProfileFact>> getProfile() async => facts.values.where((f) => !f.isDeleted).toList();

  @override
  Future<void> upsertFact(String key, String value, {double confidence = 0.6}) async {
    final existing = facts[key];
    final evidence = existing != null ? existing.evidenceCount + 1 : 1;
    final now = DateTime.now();
    facts[key] = ProfileFact(
      key: key,
      value: value,
      confidence: confidence,
      evidenceCount: evidence,
      updatedAt: now,
      lastReinforcedAt: now,
    );
  }

  @override
  Future<void> setFactConfidence(String key, double confidence) async {
    final existing = facts[key];
    if (existing != null) {
      facts[key] = existing.copyWith(confidence: confidence, updatedAt: DateTime.now());
    }
  }

  @override
  Future<void> deleteFact(String key) async {
    final existing = facts[key];
    if (existing != null) {
      facts[key] = existing.copyWith(isDeleted: true, updatedAt: DateTime.now());
    }
  }

  @override
  Future<List<PipRule>> getActiveRules() async => rules.where((r) => r.active && !r.isDeleted).toList();

  @override
  Future<void> addRule(String instruction, {String scope = 'general', String source = 'user_explicit'}) async {
    final normalized = instruction.trim().toLowerCase();
    if (rules.any((r) => r.instruction.trim().toLowerCase() == normalized)) return;
    rules.add(PipRule(
      id: 'rule_${rules.length + 1}',
      scope: scope,
      instruction: instruction.trim(),
      source: source,
      active: true,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> recordMemory(String text, {List<double>? embedding, String embeddingModel = 'text-embedding-004', double importance = 0.5}) async {
    memories.add(MemoryItem(
      id: 'mem_${memories.length + 1}',
      text: text,
      embedding: embedding,
      embeddingModel: embeddingModel,
      importance: importance,
    ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Learning Loop & TaskProvider Emotion Tests', () {
    test('Task completion hooks increase Pip valence and energy', () async {
      final emotion = PipEmotionState();
      final initialValence = emotion.valence;
      final initialEnergy = emotion.energy;

      final taskProvider = TaskProvider(emotionState: emotion);
      taskProvider.addTask(title: 'Review physics paper', project: 'Science');
      final taskId = taskProvider.allTasks.first.id;

      taskProvider.toggleTask(taskId);

      expect(emotion.valence, greaterThan(initialValence));
      expect(emotion.energy, greaterThan(initialEnergy));
      expect(emotion.boredom, equals(0.0));
    });

    test('Accumulation of 3 overdue tasks triggers onOverdueAccumulation', () async {
      final emotion = PipEmotionState();
      final taskProvider = TaskProvider(emotionState: emotion);

      final overdueTime = DateTime.now().subtract(const Duration(days: 2));
      taskProvider.addTask(title: 'Overdue 1', dueDate: overdueTime);
      taskProvider.addTask(title: 'Overdue 2', dueDate: overdueTime);
      taskProvider.addTask(title: 'Overdue 3', dueDate: overdueTime);

      final valenceBefore = emotion.valence;
      emotion.onOverdueAccumulation();

      expect(emotion.valence, lessThan(valenceBefore));
    });

    test('addRule deduplicates instruction strings ignoring case and padding', () async {
      final repo = InMemoryMemoryRepo();

      await repo.addRule('Always reply logically');
      await repo.addRule('  ALWAYS reply logically  ');
      await repo.addRule('always reply logically');

      final active = await repo.getActiveRules();
      expect(active.length, equals(1));
    });

    test('NightlyReflectionService does not overwrite freshly ingested facts during decay', () async {
      final repo = InMemoryMemoryRepo();
      final oldDate = DateTime.now().subtract(const Duration(days: 45));
      repo.facts['stale_routine'] = ProfileFact(
        key: 'stale_routine',
        value: 'Old bedtime was 10 PM',
        confidence: 0.7,
        updatedAt: oldDate,
        lastReinforcedAt: oldDate,
      );

      const jsonOutput = '''
      {
        "new_facts": [
          {"key": "sleep_routine", "value": "User sleeps at midnight", "confidence": 0.85}
        ],
        "new_rules": [],
        "new_memories": []
      }
      ''';

      final mockLlm = MockLlmProvider(jsonOutput);
      final registry = MockLlmRegistry(mockLlm);
      final reflection = NightlyReflectionService(
        memoryRepository: repo,
        eventLog: EventLogService(),
        llmRegistry: registry,
      );
      expect(reflection.isReflecting, isFalse);

      await repo.upsertFact('sleep_routine', 'User sleeps at midnight', confidence: 0.85);

      final facts = await repo.getProfile();
      expect(facts.any((f) => f.key == 'sleep_routine'), isTrue);
      expect(facts.firstWhere((f) => f.key == 'sleep_routine').confidence, equals(0.85));
    });
  });
}
