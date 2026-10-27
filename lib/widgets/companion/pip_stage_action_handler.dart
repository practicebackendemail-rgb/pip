import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../core/services/task_provider.dart';
import '../../core/services/gemini_service.dart';
import 'pip_expression_matcher.dart';
import 'pip_stage_controller.dart';
import '../pip_params.dart';

class PipStageActionHandler {
  final BuildContext context;
  final void Function(VoidCallback fn) setState;
  final void Function(String text, {bool isHappy}) speak;
  final VoidCallback onWakeUp;
  final VoidCallback onTriggerBriefing;

  PipStageActionHandler({
    required this.context,
    required this.setState,
    required this.speak,
    required this.onWakeUp,
    required this.onTriggerBriefing,
  });

  void handleQuery({
    required String query,
    required bool isSleeping,
    required TextEditingController textController,
    required void Function(bool sleeping) setIsSleeping,
    required void Function(PipMood? mood) setExplicitMood,
    required void Function(String text) setStatusText,
    required void Function(String callout) setUserPromptCallout,
    required void Function(bool loading) setIsLoading,
    required VoidCallback onShowTasks,
    required VoidCallback onClearSpeech,
  }) async {
    if (query.trim().isEmpty) return;
    final userText = query.trim();
    textController.clear();
    final q = userText.toLowerCase();

    // 1. Direct physical expression check
    final direct = PipExpressionMatcher.matchDirectAction(userText);
    if (direct != null) {
      setUserPromptCallout(userText);
      setExplicitMood(direct.mood);
      if (direct.shouldSleep) {
        setIsSleeping(true);
        setStatusText("Pip is sleeping (Zzz)");
        PipSfxService.sleep();
      } else {
        setIsSleeping(false);
        setStatusText("Pip reacted!");
      }
      speak(direct.speechText, isHappy: direct.mood == PipMood.laughing || direct.mood == PipMood.excited);
      if (!direct.shouldSleep) {
        Timer(const Duration(milliseconds: 2800), () => setExplicitMood(null));
      }
      return;
    }

    if (isSleeping) {
      onWakeUp();
      return;
    }

    final taskProv = context.read<TaskProvider>();
    final gemini = context.read<GeminiAssistantService>();

    setUserPromptCallout(userText);
    onClearSpeech();
    HapticFeedback.selectionClick();

    if (q.contains("brief") || q.contains("morning") || q.contains("update")) {
      onTriggerBriefing();
      return;
    }

    if (q.contains("task") || q.contains("agenda") || q.contains("to do") || q.contains("todo")) {
      onShowTasks();
      final pending = taskProv.allTasks.where((t) => !t.isCompleted).length;
      speak("You've got $pending pending tasks right now. Which one shall we work on?", isHappy: pending == 0);
      return;
    }

    setIsLoading(true);
    setStatusText("Pip is thinking...");
    PipSfxService.thinking();

    final reply = await gemini.sendMessage(userText, currentTasks: taskProv.allTasks);
    final cleanReply = PipStageController.executePipActions(
      reply,
      taskProv,
      onMoodDetected: (moodKey) {
        final mapped = _mapMoodString(moodKey);
        if (mapped != null) {
          setExplicitMood(mapped);
          Timer(const Duration(milliseconds: 3200), () => setExplicitMood(null));
        }
      },
    );

    setIsLoading(false);
    setStatusText("Pip replied");
    speak(cleanReply);
  }

  PipMood? _mapMoodString(String k) {
    if (k == 'happy') return PipMood.happy;
    if (k == 'sad') return PipMood.sad;
    if (k == 'laughing' || k == 'laugh') return PipMood.laughing;
    if (k == 'excited') return PipMood.excited;
    if (k == 'sleepy') return PipMood.sleepy;
    if (k == 'sleeping') return PipMood.sleeping;
    if (k == 'unsure') return PipMood.unsure;
    return null;
  }
}
