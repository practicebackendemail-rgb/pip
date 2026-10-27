import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/services/pip_sfx_service.dart';
import 'briefing_overlay_card.dart';
import 'objectives_overlay_card.dart';
import 'pip_action_dock.dart';
import 'quick_add_task_modal.dart';
import '../chat_transcript_sheet.dart';
import '../../core/services/task_provider.dart';
import '../../core/services/gemini_service.dart';

enum CompanionOverlay { none, briefing, tasks }

class PipOverlayAndDockArea extends StatelessWidget {
  final CompanionOverlay overlay;
  final String briefingContent;
  final VoidCallback onRefreshBriefing;
  final TaskProvider taskProv;
  final GeminiAssistantService? gemini;
  final PipAudioCoordinator audioCoordinator;
  final TextEditingController textController;
  final void Function(String query) onSubmitQuery;
  final VoidCallback onTriggerBriefing;
  final VoidCallback onTriggerObjectives;

  const PipOverlayAndDockArea({
    super.key,
    required this.overlay,
    required this.briefingContent,
    required this.onRefreshBriefing,
    required this.taskProv,
    required this.gemini,
    required this.audioCoordinator,
    required this.textController,
    required this.onSubmitQuery,
    required this.onTriggerBriefing,
    required this.onTriggerObjectives,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (overlay == CompanionOverlay.briefing)
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: BriefingOverlayCard(content: briefingContent, onRefresh: onRefreshBriefing),
            ),
          )
        else if (overlay == CompanionOverlay.tasks)
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: ObjectivesOverlayCard(
                taskProv: taskProv,
                onAddTask: () => QuickAddTaskModal.show(context),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: PipActionDock(
            showChips: overlay == CompanionOverlay.none,
            audioCoordinator: audioCoordinator,
            textController: textController,
            onSubmit: onSubmitQuery,
            onTriggerBriefing: onTriggerBriefing,
            onTriggerObjectives: onTriggerObjectives,
            onTriggerTranscript: () {
              HapticFeedback.selectionClick();
              PipSfxService.chirp();
              ChatTranscriptSheet.show(context, gemini?.messages ?? const []);
            },
          ),
        ),
      ],
    );
  }
}
