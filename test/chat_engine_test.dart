import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';
import 'package:personal_assistant/core/domain/pip_tool.dart';
import 'package:personal_assistant/core/services/email_service.dart';
import 'package:personal_assistant/core/services/llm_registry_service.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/core/services/task_provider.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'package:personal_assistant/models/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoopingMockLlmProvider implements LlmProvider {
  int callCount = 0;
  bool forcedPlainTextTriggered = false;

  @override
  String get id => 'looping_mock';
  @override
  String get displayName => 'Looping Mock';
  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsTools: true, supportsEmbeddings: false);

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    callCount++;
    // If tools are null, this is the forced terminal plain-text call
    if (tools == null) {
      forcedPlainTextTriggered = true;
      return const LlmResponse(text: '{"text": "Terminal loop synthesized answer", "emotion": "happy"}');
    }

    // Return continuous tool calls
    return const LlmResponse(
      text: '',
      toolCalls: [
        ToolCallRequest(toolName: 'dummy_tool', arguments: {'x': 1}),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockRegistry implements LlmRegistryService {
  final LlmProvider provider;
  MockRegistry(this.provider);
  @override
  LlmProvider getActiveProvider() => provider;
  @override
  LlmProvider getEmbeddingProvider() => provider;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyLevel0Tool extends PipTool {
  DummyLevel0Tool()
      : super(
          name: 'dummy_tool',
          description: 'A level 0 tool that runs immediately',
          confirmationLevel: ToolConfirmationLevel.level0ReadOnly,
          parameters: [],
        );

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    return {'status': 'executed'};
  }
}

class EmptyMemoryRepo implements MemoryRepository {
  @override
  Future<List<PipRule>> getActiveRules() async => [];
  @override
  Future<List<MemoryItem>> searchMemories(List<double> queryVector, {int limit = 5, String? queryText, String targetEmbeddingModel = 'text-embedding-004', double minSimilarity = 0.35}) async => [];
  @override
  Future<void> recordMemory(String text, {List<double>? embedding, String embeddingModel = 'text-embedding-004', double importance = 0.5}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestTaskProvider extends TaskProvider {
  @override
  List<TaskItem> get allTasks => [];
}

class TestEmailService implements EmailService {
  @override
  Future<List<String>> fetchUnreadSummaries() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeEventLog implements EventLogService {
  @override
  Future<void> log(String eventType, [Map<String, dynamic>? payload]) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4: Chat Engine Multi-turn & Timeout Tests', () {
    test('5-turn tool calling terminates gracefully with forced plain-text schema and isLoading == false', () async {
      final mockLlm = LoopingMockLlmProvider();
      final mockRegistry = MockRegistry(mockLlm);
      final toolRegistry = PipToolRegistry();
      toolRegistry.registerTool(DummyLevel0Tool());

      final cubit = PipStageCubit(
        llmRegistry: mockRegistry,
        eventLog: FakeEventLog(),
        emotionState: PipEmotionState(),
        memoryRepository: EmptyMemoryRepo(),
        taskProvider: TestTaskProvider(),
        emailService: TestEmailService(),
        toolRegistry: toolRegistry,
      );

      await cubit.handleQuery('Run recurring dummy actions');

      // The loop ran 5 tool-calling turns + 1 forced plain-text terminal turn = 6 chat calls
      expect(mockLlm.callCount, equals(6));
      expect(mockLlm.forcedPlainTextTriggered, isTrue);
      expect(cubit.state.isLoading, isFalse);
      // Voice is on by default, so Pip speaks its reply.
      expect(cubit.state.statusText, equals('Pip replied (happy)'));
      cubit.close();
    });
  });
}
