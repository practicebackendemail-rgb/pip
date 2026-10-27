import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:personal_assistant/core/domain/event_log.dart';
import 'package:personal_assistant/core/domain/llm_provider.dart';
import 'package:personal_assistant/core/domain/memory_models.dart';
import 'package:personal_assistant/core/domain/memory_repository.dart';
import 'package:personal_assistant/core/domain/pip_emotion_state.dart';
import 'package:personal_assistant/core/services/email_service.dart';
import 'package:personal_assistant/core/services/llm_registry_service.dart';
import 'package:personal_assistant/core/services/pip_audio_coordinator.dart';
import 'package:personal_assistant/core/services/pip_desktop_window_manager.dart';
import 'package:personal_assistant/core/services/pip_overlay_bridge.dart';
import 'package:personal_assistant/core/services/pip_sfx_service.dart';
import 'package:personal_assistant/core/services/pip_tool_registry.dart';
import 'package:personal_assistant/core/services/task_provider.dart';
import 'package:personal_assistant/features/companion/presentation/cubit/pip_stage_cubit.dart';
import 'package:personal_assistant/models/task_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StubLlmProvider implements LlmProvider {
  @override
  String get id => 'stub';
  @override
  String get displayName => 'Stub';
  @override
  LlmCapabilities get capabilities => const LlmCapabilities(supportsTools: false, supportsEmbeddings: false);
  @override
  Future<LlmResponse> chat(List<LlmMessage> messages, {List<ToolSpec>? tools, Map<String, dynamic>? jsonSchema}) async =>
      const LlmResponse(text: '{"text": "Hello world", "emotion": "happy"}');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubRegistry implements LlmRegistryService {
  final LlmProvider p = StubLlmProvider();
  @override
  LlmProvider getActiveProvider() => p;
  @override
  LlmProvider getEmbeddingProvider() => p;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubMemoryRepo implements MemoryRepository {
  @override
  Future<List<PipRule>> getActiveRules() async => [];
  @override
  Future<List<MemoryItem>> searchMemories(List<double> queryVector, {int limit = 5, String? queryText, String targetEmbeddingModel = 'text-embedding-004', double minSimilarity = 0.35}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class StubEventLogService implements EventLogService {
  @override
  Future<void> log(String eventType, [Map<String, dynamic>? payload]) async {}
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

class StubAudioCoordinator extends PipAudioCoordinator {
  bool activeListeningTriggered = false;

  @override
  Future<void> startActiveListening({required Function(String query) onQuery}) async {
    activeListeningTriggered = true;
    onQuery('Hey Pip, calculate Pi');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PipSfxService.enableAudio = false;
  });

  tearDown(() {
    PipSfxService.enableAudio = false;
  });

  group('Phase 7: Platform Presence Unit Tests', () {
    test('PipOverlayBridge handles tap_listen message and forwards to AudioCoordinator', () async {
      final cubit = PipStageCubit(
        llmRegistry: StubRegistry(),
        eventLog: StubEventLogService(),
        emotionState: PipEmotionState(),
        memoryRepository: StubMemoryRepo(),
        taskProvider: StubTaskProvider(),
        emailService: StubEmailService(),
        toolRegistry: StubPipToolRegistry(),
      );

      final audioCoordinator = StubAudioCoordinator();
      final bridge = PipOverlayBridge(cubit: cubit, audioCoordinator: audioCoordinator);
      bridge.start();

      expect(audioCoordinator.activeListeningTriggered, isFalse);

      // Directly simulate event arrival from overlay
      bridge.handleOverlayMessage(jsonEncode({'action': 'tap_listen'}));

      expect(audioCoordinator.activeListeningTriggered, isTrue);

      bridge.dispose();
    });

    test('PipDesktopWindowManager defaults and startup configuration', () async {
      final isEnabled = await PipDesktopWindowManager.isLaunchAtStartupEnabled();
      expect(isEnabled, isFalse);

      await PipDesktopWindowManager.setLaunchAtStartup(true);
      final isNowEnabled = await PipDesktopWindowManager.isLaunchAtStartupEnabled();
      expect(isNowEnabled, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('pip_launch_at_startup'), isTrue);
    });
  });
}
