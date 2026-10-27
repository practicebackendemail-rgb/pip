import 'package:injectable/injectable.dart';
import '../domain/event_log.dart';
import '../domain/memory_repository.dart';
import '../domain/pip_emotion_state.dart';
import '../services/email_service.dart';
import '../services/gemini_service.dart';
import '../services/llm_registry_service.dart';
import '../services/nightly_reflection_service.dart';
import '../services/pip_audio_coordinator.dart';
import '../services/pip_tool_registry.dart';
import '../services/sync/pip_cloud_sync_coordinator.dart';
import '../services/task_provider.dart';
import '../services/voice_service.dart';
import '../services/tools/calendar_tools.dart';
import '../services/tools/email_tools.dart';
import '../services/tools/info_tools.dart';
import '../services/tools/notes_tools.dart';
import '../services/tools/pip_internal_tools.dart';
import '../services/tools/reminder_tool.dart';
import '../services/tools/task_tools.dart';
import '../services/tools/weather_tool.dart';

@module
abstract class CoreModule {
  @lazySingleton
  TaskProvider taskProvider(EventLogService eventLogService, PipEmotionState pipEmotionState) =>
      TaskProvider(eventLog: eventLogService, emotionState: pipEmotionState);

  @lazySingleton
  GeminiAssistantService get geminiAssistantService => GeminiAssistantService();

  @lazySingleton
  EmailService get emailService => EmailService();

  @lazySingleton
  VoiceService get voiceService => VoiceService();

  @lazySingleton
  PipAudioCoordinator get pipAudioCoordinator => PipAudioCoordinator();

  @lazySingleton
  EventLogService get eventLogService => EventLogService();

  @lazySingleton
  PipEmotionState get pipEmotionState => PipEmotionState();

  @lazySingleton
  MemoryRepository get memoryRepository => SqlCipherMemoryRepository();

  @lazySingleton
  LlmRegistryService get llmRegistryService => LlmRegistryService();

  @lazySingleton
  PipCloudSyncCoordinator pipCloudSyncCoordinator(MemoryRepository memoryRepository) =>
      PipCloudSyncCoordinator(memoryRepository: memoryRepository);

  @lazySingleton
  PipToolRegistry pipToolRegistry(
    TaskProvider taskProvider,
    MemoryRepository memoryRepository,
    EmailService emailService,
  ) {
    final registry = PipToolRegistry();
    registry.registerTool(CreateTaskTool(taskProvider));
    registry.registerTool(ListTasksTool(taskProvider));
    registry.registerTool(CompleteTaskTool(taskProvider));
    registry.registerTool(GetCurrentTimeTool());
    registry.registerTool(WebSearchTool());
    registry.registerTool(WeatherTool());
    registry.registerTool(ReminderTool());
    registry.registerTool(ReadEmailsTool(emailService: emailService));
    registry.registerTool(DraftEmailTool());
    registry.registerTool(SendEmailTool(emailService: emailService));
    registry.registerTool(ListCalendarEventsTool());
    registry.registerTool(CreateCalendarEventTool());
    registry.registerTool(SaveNoteTool(memoryRepository: memoryRepository));
    registry.registerTool(SearchNotesTool(memoryRepository: memoryRepository));
    registry.registerTool(LearnFactTool(memoryRepository));
    registry.registerTool(AddRuleTool(memoryRepository));
    return registry;
  }

  @lazySingleton
  NightlyReflectionService nightlyReflectionService(
    MemoryRepository memoryRepository,
    EventLogService eventLog,
    LlmRegistryService llmRegistry,
  ) =>
      NightlyReflectionService(
        memoryRepository: memoryRepository,
        eventLog: eventLog,
        llmRegistry: llmRegistry,
      );
}
