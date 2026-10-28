import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/domain/event_log.dart';
import '../../../../core/domain/llm_provider.dart';
import '../../../../core/domain/memory_repository.dart';
import '../../../../core/domain/pip_emotion_state.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/llm_registry_service.dart';
import '../../../../core/services/llm_error_messages.dart';
import '../../../../core/services/pip_home_widget_service.dart';
import '../../../../core/services/pip_profile_service.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../../../core/services/pip_tool_registry.dart';
import '../../../../core/services/task_provider.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../widgets/companion/pip_expression_matcher.dart';
import '../../../../widgets/companion/pip_speech_coordinator.dart';
import '../../../../widgets/companion/pip_stage_controller.dart';
import '../../../../widgets/pip_params.dart';
import '../../../activity/presentation/activity_cubit.dart';
import '../../domain/pip_action_speech.dart';
import '../../domain/pip_briefing.dart';
import '../../domain/pip_character_bible.dart';
import '../../domain/pip_structured_reply.dart';
import 'pip_chat_engine.dart';
import 'pip_memory_helper.dart';
import 'pip_stage_state.dart';
import 'pip_tool_coordinator.dart';
import 'pip_voice_output.dart';

@injectable
class PipStageCubit extends Cubit<PipStageState> {
  final LlmRegistryService llmRegistry;
  final EventLogService eventLog;
  final PipEmotionState emotionState;
  final MemoryRepository memoryRepository;
  final TaskProvider taskProvider;
  final EmailService emailService;
  final PipToolRegistry toolRegistry;
  final PipSpeechCoordinator _speech = PipSpeechCoordinator();
  final PipVoiceOutput _voice;
  late final PipToolCoordinator _toolCoordinator;
  late final PipMemoryHelper _memoryHelper;
  late final PipChatEngine _chatEngine;

  PipStageCubit({
    required this.llmRegistry,
    required this.eventLog,
    required this.emotionState,
    required this.memoryRepository,
    required this.taskProvider,
    required this.emailService,
    required this.toolRegistry,
    VoiceService? voiceService,
  })  : _voice = PipVoiceOutput(voiceService),
        super(const PipStageState()) {
    _toolCoordinator = PipToolCoordinator(toolRegistry: toolRegistry, eventLog: eventLog);
    _memoryHelper = PipMemoryHelper(memoryRepository);
    _chatEngine = PipChatEngine(toolCoordinator: _toolCoordinator);
    _voice.enabled.then((on) => isClosed ? null : emit(state.copyWith(isSilentCompanionMode: !on)));
    _initGreeting();
    _syncHomeWidget();
  }

  void _syncHomeWidget() => PipHomeWidgetService.updateWidget(
      mood: state.currentMood.name,
      statusText: state.statusText,
      pendingTasksCount: taskProvider.allTasks.where((t) => !t.isCompleted).length);

  void _initGreeting() => speak("Hi there! I'm Pip, your desk companion. What are we building or tackling today?", isHappy: true);

  void speak(String text, {bool isHappy = false, PipSound? sound}) {
    emit(state.copyWith(speechText: "", isTypewriting: true, currentMood: PipMood.talking));
    _speech.triggerSpeech(
      fullText: text,
      isHappy: isHappy,
      sound: sound,
      onTick: () => emit(state.copyWith(speechText: _speech.displayedSpeechText, isTypewriting: true)),
      onDone: () => emit(state.copyWith(
        speechText: _speech.displayedSpeechText,
        isTypewriting: false,
        currentMood: state.isSleeping ? PipMood.sleeping : PipMood.idle,
      )),
    );
    _voice.say(text);
  }

  void wakeUp() {
    PipSfxService.happy();
    emotionState.onWakeTriggered();
    eventLog.log('pip_awakened');
    emit(state.copyWith(isSleeping: false, currentMood: PipMood.excited, statusText: "Pip is wide awake!"));
    speak("I'm awake and ready to go!", isHappy: true);
    Timer(const Duration(milliseconds: 1400), () {
      if (!isClosed && state.currentMood == PipMood.excited) emit(state.copyWith(currentMood: PipMood.idle));
    });
  }

  void sleep() {
    PipSfxService.sleep();
    emotionState.onSleepTriggered();
    eventLog.log('pip_slept');
    emit(state.copyWith(isSleeping: true, currentMood: PipMood.sleeping, statusText: "Pip is sleeping (Zzz)"));
    speak("Entering sleep mode... Zzz. Say 'Hey Pip' or tap me to wake me up.");
  }

  /// Thumbs feedback on Pip's current reply; feeds the learning loop.
  void rateReply({required bool positive}) {
    final text = state.speechText;
    if (text.isEmpty) return;
    eventLog.log(positive ? 'reply_thumbs_up' : 'reply_thumbs_down', {'reply': text.length > 160 ? text.substring(0, 160) : text});
    emit(state.copyWith(statusText: positive ? "Thanks for the feedback!" : "Noted, I'll adjust."));
  }

  void clearSpeechBubble() {
    _speech.clear();
    emit(state.copyWith(speechText: "", isTypewriting: false));
  }

  Future<void> handleQuery(String query) async {
    final userText = query.trim();
    if (userText.isEmpty) return;

    eventLog.log('user_query', {'text': userText});
    emotionState.onUserInteraction();

    // A spoken "yes"/"no" answers a pending confirmation instead of starting a new chat.
    final pending = state.pendingActionConfirmation;
    if (pending != null) {
      final answer = parseConfirmation(userText);
      if (answer == ConfirmAnswer.no) return cancelPendingAction();
      if (answer == ConfirmAnswer.yes) {
        if (!needsTapToConfirm(pending['level'] as String?)) return confirmPendingAction();
        return speak("This one's important, so tap Execute to confirm.");
      }
    }

    final direct = PipExpressionMatcher.matchDirectAction(userText);
    if (direct != null) {
      emit(state.copyWith(userPromptCallout: userText, currentMood: direct.mood ?? state.currentMood));
      if (direct.shouldSleep) {
        sleep();
      } else {
        emit(state.copyWith(isSleeping: false, statusText: "Pip reacted!"));
        speak(direct.speechText, isHappy: direct.mood == PipMood.laughing || direct.mood == PipMood.excited);
      }
      return;
    }

    if (state.isSleeping) {
      wakeUp();
      return;
    }

    emit(state.copyWith(userPromptCallout: userText, speechText: "", isLoading: true, statusText: "Pip is thinking...", currentMood: PipMood.thinking));
    PipSfxService.thinking();

    try {
      final provider = llmRegistry.getActiveProvider();
      final embeddingProvider = llmRegistry.getEmbeddingProvider();

      final activeRules = await memoryRepository.getActiveRules();
      final memories = await _memoryHelper.retrieveRelevantMemories(queryText: userText, embeddingProvider: embeddingProvider);

      final systemContext = PipCharacterBible.buildSystemPrompt(
        emotionContext: emotionState.toPromptContext(),
        humorLevel: await PipProfileService.humor(),
        activeRules: activeRules.map((r) => r.instruction).toList(),
        relevantMemories: memories.map((m) => m.text).toList(),
        toolsContext: toolRegistry.buildToolsPromptContext(),
      );

      final outcome = await _chatEngine.run(
        provider: provider,
        systemContext: systemContext,
        userText: userText,
        toolSpecs: provider.capabilities.supportsTools ? toolRegistry.toToolSpecs() : null,
      );
      final pending = outcome.pendingConfirmation;
      if (pending != null) {
        emit(state.copyWith(
          isLoading: false,
          currentMood: PipMood.idle,
          statusText: "Confirmation Required",
          pendingActionConfirmation: {
            'tool': pending.pendingToolName,
            'args': pending.pendingArgs,
            'description': pending.pendingDescription,
            'level': pending.pendingLevel?.name,
          },
        ));
        final ask = describePendingAction(pending.pendingToolName ?? '', pending.pendingArgs ?? const {});
        final tapOnly = needsTapToConfirm(pending.pendingLevel?.name);
        speak('$ask ${tapOnly ? 'Tap Execute to confirm.' : 'Just say yes or no.'}');
        return;
      }
      await _finishReply(outcome.reply!, embeddingProvider);
    } catch (e) {
      emit(state.copyWith(statusText: "Pip had trouble responding", currentMood: PipMood.unsure));
      debugPrint('Pip reply failed: $e');
      speak(describeLlmError(e));
    } finally {
      if (state.isLoading) emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _finishReply(PipStructuredReply parsed, LlmProvider embeddingProvider) async {
    final cleanText = PipStageController.executePipActions(parsed.text, taskProvider);
    final resolvedMood = parsed.toPipMood();
    await _memoryHelper.saveLearnedMemories(parsed.memoryCandidates, embeddingProvider);

    final sound = PipSfxService.forEmotion(parsed.emotion);
    final silent = state.isSilentCompanionMode;
    if (silent) PipSfxService.play(sound);
    emit(state.copyWith(
      isLoading: false,
      statusText: "Pip ${silent ? 'reacted' : 'replied'} (${parsed.emotion})",
      currentMood: resolvedMood,
      speechText: cleanText,
      isTypewriting: silent ? false : null,
    ));
    if (!silent) speak(cleanText, isHappy: parsed.emotion == 'happy' || parsed.emotion == 'excited', sound: sound);
  }

  /// Turns Pip's spoken voice on or off; remembered across launches.
  Future<void> setVoiceEnabled(bool on) async {
    await _voice.setEnabled(on);
    emit(state.copyWith(isSilentCompanionMode: !on));
  }

  Future<void> confirmPendingAction() async {
    final pending = state.pendingActionConfirmation;
    if (pending == null) return;
    final toolName = pending['tool'] as String;
    final args = pending['args'] as Map<String, dynamic>;
    final tool = toolRegistry.getTool(toolName);

    emit(state.copyWith(clearPendingAction: true, isLoading: true, statusText: "Executing action..."));
    if (tool != null) {
      try {
        final res = await tool.execute(args);
        ActivityRecorder.tool(toolName, args, res);
        final error = res['error'];
        eventLog.log('tool_confirmed_and_executed', {'tool': toolName, 'ok': error == null});
        if (error != null) {
          emit(state.copyWith(isLoading: false, currentMood: PipMood.unsure, statusText: "Action failed"));
          speak("That didn't work: $error");
          return;
        }
        PipSfxService.happy();
        emit(state.copyWith(isLoading: false, currentMood: PipMood.happy, statusText: "Action complete!"));
        speak(describeToolResult(toolName, res), isHappy: true);
      } catch (e) {
        emit(state.copyWith(isLoading: false, currentMood: PipMood.unsure, statusText: "Execution error"));
        debugPrint('Confirmed action failed: $e');
        speak("Sorry, that didn't work. Try again in a moment.");
      }
    }
  }

  void cancelPendingAction() {
    PipSfxService.chirp();
    eventLog.log('tool_action_cancelled', {'tool': state.pendingActionConfirmation?['tool']});
    emit(state.copyWith(clearPendingAction: true, statusText: "Action cancelled", currentMood: PipMood.idle));
    speak("Okay, I won't do that.");
  }

  Future<void> triggerBriefing() async {
    eventLog.log('briefing_opened');
    emit(state.copyWith(isLoading: true, isSleeping: false, statusText: "Pip is digesting your agenda...", currentMood: PipMood.thinking));

    final emails = await emailService.fetchUnreadSummaries();
    final tasks = taskProvider.allTasks.where((t) => !t.isCompleted).toList();

    try {
      final text = await PipBriefing.compose(llmRegistry.getActiveProvider(),
          tasks: tasks.map((t) => t.title).toList(), emails: emails);
      ActivityRecorder.entry(PipBriefing.activity(tasks: tasks.length, emails: emails.length));
      emit(state.copyWith(briefingContent: text, isLoading: false, statusText: "Briefing ready", currentMood: PipMood.happy));
      speak("Here's your day. Ask me about anything in it.", isHappy: true);
    } catch (e) {
      emit(state.copyWith(isLoading: false, statusText: "Failed to generate briefing", currentMood: PipMood.unsure));
      debugPrint('Briefing failed: $e');
      speak(describeLlmError(e));
    }
  }

  @override
  Future<void> close() {
    _speech.dispose();
    _voice.stop();
    return super.close();
  }
}
