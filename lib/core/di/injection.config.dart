// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/companion/presentation/cubit/pip_stage_cubit.dart'
    as _i528;
import '../domain/event_log.dart' as _i573;
import '../domain/memory_repository.dart' as _i621;
import '../domain/pip_emotion_state.dart' as _i42;
import '../services/email_service.dart' as _i233;
import '../services/gemini_service.dart' as _i846;
import '../services/llm_registry_service.dart' as _i404;
import '../services/nightly_reflection_service.dart' as _i336;
import '../services/pip_audio_coordinator.dart' as _i458;
import '../services/pip_tool_registry.dart' as _i239;
import '../services/sync/pip_cloud_sync_coordinator.dart' as _i463;
import '../services/task_provider.dart' as _i171;
import '../services/voice_service.dart' as _i950;
import 'core_module.dart' as _i154;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  _i174.GetIt init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final coreModule = _$CoreModule();
    gh.lazySingleton<_i846.GeminiAssistantService>(
      () => coreModule.geminiAssistantService,
    );
    gh.lazySingleton<_i233.EmailService>(() => coreModule.emailService);
    gh.lazySingleton<_i950.VoiceService>(() => coreModule.voiceService);
    gh.lazySingleton<_i458.PipAudioCoordinator>(
      () => coreModule.pipAudioCoordinator,
    );
    gh.lazySingleton<_i573.EventLogService>(() => coreModule.eventLogService);
    gh.lazySingleton<_i42.PipEmotionState>(() => coreModule.pipEmotionState);
    gh.lazySingleton<_i621.MemoryRepository>(() => coreModule.memoryRepository);
    gh.lazySingleton<_i404.LlmRegistryService>(
      () => coreModule.llmRegistryService,
    );
    gh.lazySingleton<_i463.PipCloudSyncCoordinator>(
      () => coreModule.pipCloudSyncCoordinator(gh<_i621.MemoryRepository>()),
    );
    gh.lazySingleton<_i171.TaskProvider>(
      () => coreModule.taskProvider(
        gh<_i573.EventLogService>(),
        gh<_i42.PipEmotionState>(),
      ),
    );
    gh.lazySingleton<_i336.NightlyReflectionService>(
      () => coreModule.nightlyReflectionService(
        gh<_i621.MemoryRepository>(),
        gh<_i573.EventLogService>(),
        gh<_i404.LlmRegistryService>(),
      ),
    );
    gh.lazySingleton<_i239.PipToolRegistry>(
      () => coreModule.pipToolRegistry(
        gh<_i171.TaskProvider>(),
        gh<_i621.MemoryRepository>(),
        gh<_i233.EmailService>(),
      ),
    );
    gh.factory<_i528.PipStageCubit>(
      () => _i528.PipStageCubit(
        llmRegistry: gh<_i404.LlmRegistryService>(),
        eventLog: gh<_i573.EventLogService>(),
        emotionState: gh<_i42.PipEmotionState>(),
        memoryRepository: gh<_i621.MemoryRepository>(),
        taskProvider: gh<_i171.TaskProvider>(),
        emailService: gh<_i233.EmailService>(),
        toolRegistry: gh<_i239.PipToolRegistry>(),
        voiceService: gh<_i950.VoiceService>(),
      ),
    );
    return this;
  }
}

class _$CoreModule extends _i154.CoreModule {}
