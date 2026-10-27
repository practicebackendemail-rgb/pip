import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import '../../../../core/domain/event_log.dart';
import '../../../../core/domain/llm_provider.dart';
import '../../../../core/domain/memory_repository.dart';
import '../../../../core/domain/pip_emotion_state.dart';
import '../../../../core/domain/pip_tool.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/services/llm_registry_service.dart';
import '../../../../core/services/pip_home_widget_service.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../../../core/services/pip_tool_registry.dart';
import '../../../../core/services/task_provider.dart';
import '../../../../widgets/companion/pip_expression_matcher.dart';
import '../../../../widgets/companion/pip_overlay_and_dock_area.dart';
import '../../../../widgets/companion/pip_speech_coordinator.dart';
import '../../../../widgets/companion/pip_stage_controller.dart';
import '../../../../widgets/pip_params.dart';
import '../../domain/pip_character_bible.dart';
import '../../domain/pip_structured_reply.dart';
import 'pip_stage_state.dart';

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

  PipStageCubit({
    required this.llmRegistry,
    required this.eventLog,
    required this.emotionState,
    required this.memoryRepository,
    required this.taskProvider,
    required this.emailService,
    required this.toolRegistry,
  }) : super(const PipStageState()) {
    _initGreeting();
    _syncHomeWidget();
  }

  void _syncHomeWidget() {
    final pending = taskProvider.allTasks.where((t) => !t.isCompleted).length;
    PipHomeWidgetService.updateWidget(
      mood: state.currentMood.name,
      statusText: state.statusText,
      pendingTasksCount: pending,
    );
  }

  void _initGreeting() {
    speak("Hi there! I'm Pip, your desk companion. What are we building or tackling today?", isHappy: true);
  }

  void speak(String text, {bool isHappy = false}) {
    emit(state.copyWith(speechText: "", isTypewriting: true, currentMood: PipMood.talking));
    _speech.triggerSpeech(
      fullText: text,
      isHappy: isHappy,
      onTick: () => emit(state.copyWith(speechText: _speech.displayedSpeechText, isTypewriting: true)),
      onDone: () => emit(state.copyWith(
        speechText: _speech.displayedSpeechText,
        isTypewriting: false,
        currentMood: state.isSleeping ? PipMood.sleeping : PipMood.idle,
      )),
    );
  }

  void wakeUp() {
    PipSfxService.happy();
    emotionState.onWakeTriggered();
    eventLog.log('pip_awakened');
    emit(state.copyWith(
      isSleeping: false,
      currentMood: PipMood.excited,
      statusText: "Pip is wide awake!",
    ));
    speak("I'm awake and ready to go!", isHappy: true);
    Timer(const Duration(milliseconds: 1400), () {
      if (!isClosed && state.currentMood == PipMood.excited) {
        emit(state.copyWith(currentMood: PipMood.idle));
      }
    });
  }

  void sleep() {
    PipSfxService.sleep();
    emotionState.onSleepTriggered();
    eventLog.log('pip_slept');
    emit(state.copyWith(
      isSleeping: true,
      overlay: CompanionOverlay.none,
      currentMood: PipMood.sleeping,
      statusText: "Pip is sleeping (Zzz)",
    ));
    speak("Entering sleep mode... Zzz. Say 'Hey Pip' or tap me to wake me up.");
  }

  void setOverlay(CompanionOverlay overlay) {
    emit(state.copyWith(overlay: overlay));
  }

  void dismissOverlay() {
    emit(state.copyWith(overlay: CompanionOverlay.none));
  }

  void clearSpeechBubble() {
    _speech.clear();
    emit(state.copyWith(speechText: "", isTypewriting: false));
  }

  Future<void> handleQuery(String query) async {
    final userText = query.trim();
    if (userText.isEmpty) return;
    final q = userText.toLowerCase();

    eventLog.log('user_query', {'text': userText});
    emotionState.onUserInteraction();

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

    emit(state.copyWith(userPromptCallout: userText, speechText: ""));

    if (q.contains("brief") || q.contains("morning") || q.contains("update")) {
      await triggerBriefing();
      return;
    }

    if (q.contains("task") || q.contains("agenda") || q.contains("to do") || q.contains("todo")) {
      emit(state.copyWith(overlay: CompanionOverlay.tasks, statusText: "Viewing your objectives"));
      final pending = taskProvider.allTasks.where((t) => !t.isCompleted).length;
      speak("You've got $pending pending tasks right now. Which one shall we work on?", isHappy: pending == 0);
      return;
    }

    emit(state.copyWith(isLoading: true, statusText: "Pip is thinking...", currentMood: PipMood.thinking));
    PipSfxService.thinking();

    try {
      final provider = llmRegistry.getActiveProvider();
      final embeddingProvider = llmRegistry.getEmbeddingProvider();

      // Retrieve relevant memories & rules
      final activeRules = await memoryRepository.getActiveRules();

      // Semantic embedding of user query
      List<double> queryVector = const [];
      if (userText.trim().split(RegExp(r'\s+')).length > 2 &&
          embeddingProvider.capabilities.supportsEmbeddings) {
        try {
          final embList = await embeddingProvider.embed([userText.trim()]);
          if (embList.isNotEmpty && embList.first.isNotEmpty) {
            queryVector = embList.first;
          }
        } catch (e) {
          debugPrint('Query embedding error: $e');
        }
      }

      final relevantMemories = await memoryRepository.searchMemories(
        queryVector,
        limit: 3,
        queryText: userText,
      );

      final systemContext = PipCharacterBible.buildSystemPrompt(
        emotionContext: emotionState.toPromptContext(),
        humorLevel: 0.6,
        activeRules: activeRules.map((r) => r.instruction).toList(),
        relevantMemories: relevantMemories.map((m) => m.text).toList(),
        toolsContext: toolRegistry.buildToolsPromptContext(),
      );
      final messages = [
        LlmMessage(role: 'system', content: systemContext),
        LlmMessage(role: 'user', content: userText),
      ];

      LlmResponse response;
      int iterations = 0;
      final toolSpecs = provider.capabilities.supportsTools ? toolRegistry.toToolSpecs() : null;

      // Multi-turn tool calling loop (capped at 5 iterations)
      while (iterations < 5) {
        iterations++;
        response = await provider.chat(
          messages,
          tools: toolSpecs,
          jsonSchema: toolSpecs == null ? PipStructuredReply.jsonSchema : null,
        );

        // Check for native tool calls or structured JSON tool calls
        List<ToolCallRequest> callsToExecute = List.from(response.toolCalls);
        PipStructuredReply? structured;

        if (callsToExecute.isEmpty) {
          structured = PipStructuredReply.parseRaw(response.text);
          if (structured.toolCallName != null && structured.toolCallName!.isNotEmpty) {
            callsToExecute.add(ToolCallRequest(
              toolName: structured.toolCallName!,
              arguments: structured.toolCallArgs ?? {},
            ));
          }
        }

        if (callsToExecute.isEmpty) {
          // Model completed its thoughts; parse final text
          final parsed = structured ?? PipStructuredReply.parseRaw(response.text);
          final cleanText = PipStageController.executePipActions(parsed.text, taskProvider);
          final resolvedMood = parsed.toPipMood();

          // Save learned memory candidates
          for (final candidate in parsed.memoryCandidates) {
            List<double>? candidateVector;
            if (embeddingProvider.capabilities.supportsEmbeddings) {
              try {
                final emb = await embeddingProvider.embed([candidate]);
                if (emb.isNotEmpty && emb.first.isNotEmpty) candidateVector = emb.first;
              } catch (_) {}
            }
            await memoryRepository.recordMemory(candidate, embedding: candidateVector, importance: 0.8);
          }

          if (parsed.emotion == 'happy' || parsed.emotion == 'proud' || parsed.emotion == 'excited') {
            PipSfxService.happy();
          }

          if (state.isSilentCompanionMode) {
            emit(state.copyWith(
              isLoading: false,
              statusText: "Pip reacted (${parsed.emotion})",
              currentMood: resolvedMood,
              speechText: cleanText,
              isTypewriting: false,
            ));
          } else {
            emit(state.copyWith(
              isLoading: false,
              statusText: "Pip replied (${parsed.emotion})",
              currentMood: resolvedMood,
            ));
            speak(cleanText, isHappy: parsed.emotion == 'happy' || parsed.emotion == 'excited');
          }
          return;
        }

        // Execute tool calls adhering to confirmation levels
        for (final call in callsToExecute) {
          final tool = toolRegistry.getTool(call.toolName);
          if (tool == null) continue;

          // If tool requires confirmation (Level 1 or 3), halt loop and prompt user
          if (tool.confirmationLevel == ToolConfirmationLevel.level1ConfirmAction ||
              tool.confirmationLevel == ToolConfirmationLevel.level3DangerousDoubleConfirm) {
            await _processToolCall(call.toolName, call.arguments, response.text, PipMood.idle);
            return;
          }

          // Level 0 or 2: Execute immediately
          eventLog.log('tool_invoked', {'tool': call.toolName, 'args': call.arguments});
          final result = await tool.execute(call.arguments);
          eventLog.log('tool_success', {'tool': call.toolName, 'result': result});

          messages.add(LlmMessage(role: 'assistant', content: 'Invoked tool: ${call.toolName}'));
          messages.add(LlmMessage(role: 'user', content: 'Tool Result for ${call.toolName}: ${jsonEncode(result)}'));
        }
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, statusText: "Pip had trouble responding", currentMood: PipMood.unsure));
      speak("My circuits encountered an error: $e");
    }
  }

  Future<void> _processToolCall(String name, Map<String, dynamic> args, String spokenReply, PipMood mood) async {
    final tool = toolRegistry.getTool(name);
    if (tool == null) {
      emit(state.copyWith(isLoading: false, currentMood: mood));
      speak(spokenReply);
      return;
    }

    eventLog.log('tool_invoked', {'tool': name, 'args': args, 'level': tool.confirmationLevel.name});

    // Level 0 (Read-Only) or Level 2 (Report After) -> execute immediately
    if (tool.confirmationLevel == ToolConfirmationLevel.level0ReadOnly ||
        tool.confirmationLevel == ToolConfirmationLevel.level2ReportAfter) {
      try {
        final result = await tool.execute(args);
        eventLog.log('tool_success', {'tool': name, 'result': result});
        emit(state.copyWith(isLoading: false, currentMood: mood, statusText: "Executed ${tool.name}"));
        speak(spokenReply.isNotEmpty ? spokenReply : "Done! I took care of that for you.", isHappy: true);
      } catch (e) {
        emit(state.copyWith(isLoading: false, currentMood: PipMood.unsure, statusText: "Action failed"));
        speak("I encountered an issue executing $name: $e");
      }
      return;
    }

    // Level 1 (Confirm Action) or Level 3 (Dangerous Double-Confirm) -> Prompt user via confirmation card
    emit(state.copyWith(
      isLoading: false,
      currentMood: PipMood.idle,
      statusText: "Confirmation Required",
      pendingActionConfirmation: {
        'tool': name,
        'args': args,
        'description': tool.description,
        'level': tool.confirmationLevel.name,
      },
    ));
    speak(spokenReply.isNotEmpty ? spokenReply : "Should I proceed with executing $name?");
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
        PipSfxService.happy();
        eventLog.log('tool_confirmed_and_executed', {'tool': toolName, 'result': res});
        emit(state.copyWith(isLoading: false, currentMood: PipMood.happy, statusText: "Action complete!"));
        speak("Action confirmed and executed successfully!", isHappy: true);
      } catch (e) {
        emit(state.copyWith(isLoading: false, currentMood: PipMood.unsure, statusText: "Execution error"));
        speak("Error executing action: $e");
      }
    }
  }

  void cancelPendingAction() {
    PipSfxService.chirp();
    eventLog.log('tool_action_cancelled', {'tool': state.pendingActionConfirmation?['tool']});
    emit(state.copyWith(clearPendingAction: true, statusText: "Action cancelled", currentMood: PipMood.idle));
    speak("Alright, I won't execute that action.");
  }

  Future<void> triggerBriefing() async {
    emit(state.copyWith(
      isLoading: true,
      isSleeping: false,
      overlay: CompanionOverlay.briefing,
      userPromptCallout: "☀️ Daily Briefing",
      statusText: "Pip is digesting your agenda...",
      currentMood: PipMood.thinking,
    ));

    final emails = await emailService.fetchUnreadSummaries();
    final tasks = taskProvider.allTasks.where((t) => !t.isCompleted).toList();

    try {
      final provider = llmRegistry.getActiveProvider();
      final prompt = 'Summarize daily agenda concisely:\nTasks: ${tasks.map((t) => t.title).join(", ")}\nEmails: ${emails.join(", ")}';
      final response = await provider.chat([LlmMessage(role: 'user', content: prompt)]);

      emit(state.copyWith(
        briefingContent: response.text,
        isLoading: false,
        statusText: "Morning Briefing Ready",
        currentMood: PipMood.happy,
      ));
      speak("Here is your morning agenda! Check the card below for the action plan.", isHappy: true);
    } catch (e) {
      emit(state.copyWith(isLoading: false, statusText: "Failed to generate briefing", currentMood: PipMood.unsure));
      speak("Could not load briefing: $e");
    }
  }

  @override
  Future<void> close() {
    _speech.dispose();
    return super.close();
  }
}
