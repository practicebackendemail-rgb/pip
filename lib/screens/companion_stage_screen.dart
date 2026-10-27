import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/theme/pip_theme.dart';
import '../../core/services/task_provider.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../../features/companion/presentation/cubit/pip_stage_state.dart';
import '../widgets/chat_transcript_sheet.dart';
import '../widgets/comic_speech_bubble.dart';
import '../widgets/companion/pip_ambient_glow.dart';
import '../widgets/companion/pip_action_confirmation_banner.dart';
import '../widgets/companion/pip_overlay_and_dock_area.dart';
import '../widgets/companion/pip_prompt_status_pill.dart';
import '../widgets/companion/pip_stage_header.dart';
import '../widgets/companion/pip_stage_scenery.dart';
import '../widgets/pip_companion.dart';

/// Pure Clean Architecture stage screen powered exclusively by PipStageCubit (Zero setState).
class CompanionStageScreen extends StatefulWidget {
  /// True inside the wide (desktop) home, where the rail handles navigation.
  final bool embedded;

  const CompanionStageScreen({super.key, this.embedded = false});

  @override
  State<CompanionStageScreen> createState() => _CompanionStageScreenState();
}

class _CompanionStageScreenState extends State<CompanionStageScreen> {
  final TextEditingController _textController = TextEditingController();

  /// Pip says something different each time it's poked, instead of one canned line.
  static const _tapLines = [
    "Hi! Ask me anything, or tap Briefing to catch up.",
    "Boop! That tickles my sensors.",
    "Still here, still shiny. What's next?",
    "Need a hand? I have two. Well, grippers.",
  ];
  int _tapCount = 0;

  @override
  void initState() {
    super.initState();
    PipProfileService.userName().then((name) {
      if (!mounted || name == null) return;
      context.read<PipStageCubit>().speak("${PipProfileService.greeting(name)} What are we tackling today?", isHappy: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = getIt<PipAudioCoordinator>();
      final cubit = context.read<PipStageCubit>();
      audio.onCommandReceived = (query) {
        if (cubit.state.isSleeping) {
          cubit.wakeUp();
        } else {
          cubit.handleQuery(query);
        }
      };
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = getIt<PipAudioCoordinator>();
    final taskProv = getIt<TaskProvider>();
    final cubit = context.read<PipStageCubit>();

    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) {
        return BlocBuilder<PipStageCubit, PipStageState>(
          builder: (context, state) {
            final hasSpeech = state.speechText.trim().isNotEmpty;

            return Scaffold(
              backgroundColor: PipColors.background,
              body: PipStageScenery(
                child: Stack(
                  children: [
                    const PipAmbientGlow(),
                    PipStageHeader(
                      hasActiveOverlay: state.overlay != CompanionOverlay.none,
                      onDismissOverlay: cubit.dismissOverlay,
                      messages: const [],
                      audioCoordinator: audio,
                      showNavActions: !widget.embedded,
                    ),
                    SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          if (hasSpeech)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: ComicSpeechBubble(
                                text: state.speechText,
                                isStreaming: state.isTypewriting,
                                onDismiss: cubit.clearSpeechBubble,
                                onRate: (positive) => cubit.rateReply(positive: positive),
                                onOpenFullLog: () => ChatTranscriptSheet.show(context, const []),
                              ).animate().fadeIn(duration: AppMotionTokens.fast).slideY(begin: 0.08, end: 0),
                            )
                          else
                            const SizedBox(height: 36),
                          Expanded(
                            child: Center(
                              child: Hero(
                                tag: 'pip_companion',
                                child: PipDeskCompanion(
                                  width: state.overlay == CompanionOverlay.none ? 310 : 230,
                                  height: state.overlay == CompanionOverlay.none ? 230 : 160,
                                  mood: audio.isActiveListening ? PipMood.listening : state.currentMood,
                                  onTap: () {
                                    if (state.isSleeping) {
                                      cubit.wakeUp();
                                    } else {
                                      cubit.speak(_tapLines[_tapCount++ % _tapLines.length], isHappy: true);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          PipPromptStatusPill(
                            userPromptCallout: state.userPromptCallout,
                            statusText: state.statusText,
                            isListening: audio.isActiveListening,
                          ),
                          if (state.pendingActionConfirmation != null)
                            PipActionConfirmationBanner(
                              confirmation: state.pendingActionConfirmation!,
                              onConfirm: cubit.confirmPendingAction,
                              onCancel: cubit.cancelPendingAction,
                            ).animate().fadeIn(duration: AppMotionTokens.fast).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                          PipOverlayAndDockArea(
                            overlay: state.overlay,
                            briefingContent: state.briefingContent,
                            onRefreshBriefing: cubit.triggerBriefing,
                            taskProv: taskProv,
                            gemini: null,
                            audioCoordinator: audio,
                            textController: _textController,
                            onSubmitQuery: (q) {
                              _textController.clear();
                              cubit.handleQuery(q);
                            },
                            onTriggerBriefing: cubit.triggerBriefing,
                            onTriggerObjectives: () => cubit.setOverlay(CompanionOverlay.tasks),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
