import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';
import 'package:personal_assistant/core/services/email_service.dart';
import 'package:personal_assistant/core/services/llm_registry_service.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/core/services/task_provider.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'package:personal_assistant/models/task_model.dart';

class StubLlmProvider implements LlmProvider {
  final String replyText;
  StubLlmProvider(this.replyText);

  @override
  String get id => 'stub_llm';
  @override
  String get displayName => 'Stub LLM';
  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsTools: false, supportsEmbeddings: false);

  @override
  Future<LlmResponse> chat(
    List<LlmMessage> messages, {
    List<ToolSpec>? tools,
    Map<String, dynamic>? jsonSchema,
  }) async {
    return LlmResponse(text: replyText);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubLlmRegistryService implements LlmRegistryService {
  final LlmProvider provider;
  StubLlmRegistryService(this.provider);

  @override
  LlmProvider getActiveProvider() => provider;

  @override
  LlmProvider getEmbeddingProvider() => provider;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubEventLogService implements EventLogService {
  @override
  Future<void> log(String eventType, [Map<String, dynamic>? payload]) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubMemoryRepository implements MemoryRepository {
  @override
  Future<List<PipRule>> getActiveRules() async => [];

  @override
  Future<List<MemoryItem>> searchMemories(
    List<double> queryVector, {
    int limit = 5,
    String? queryText,
    double minSimilarity = 0.3,
  }) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubTaskProvider implements TaskProvider {
  @override
  List<TaskItem> get allTasks => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubEmailService implements EmailService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubPipToolRegistry implements PipToolRegistry {
  @override
  String buildToolsPromptContext() => '';

  @override
  List<ToolSpec> toToolSpecs() => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PipStageCubit plain-text query completes with isLoading == false', () async {
    const rawReply = '{"text": "Bazinga! That is logically indisputable.", "emotion": "happy"}';
    final stubLlm = StubLlmProvider(rawReply);
    final stubRegistry = StubLlmRegistryService(stubLlm);

    final cubit = PipStageCubit(
      llmRegistry: stubRegistry,
      eventLog: StubEventLogService(),
      emotionState: PipEmotionState(),
      memoryRepository: StubMemoryRepository(),
      taskProvider: StubTaskProvider(),
      emailService: StubEmailService(),
      toolRegistry: StubPipToolRegistry(),
    );

    expect(cubit.state.isLoading, isFalse);

    await cubit.handleQuery('What is the best integer?');

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.speechText, isNotEmpty);
    cubit.close();
  });
}
