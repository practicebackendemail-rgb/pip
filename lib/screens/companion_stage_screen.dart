import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/di/injection.dart';
import '../../core/localization/l10n_extension.dart';
import '../../core/routes/app_routes.dart';
import '../../core/services/pip_audio_coordinator.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../../core/theme/pip_theme.dart';
import '../../features/companion/presentation/cubit/pip_stage_cubit.dart';
import '../../features/companion/presentation/cubit/pip_stage_state.dart';
import '../../features/companion/presentation/widgets/heard_caption.dart';
import '../../features/companion/presentation/widgets/pip_screen_context.dart';
import '../../features/presence/presence_mode.dart';
import '../widgets/comic_speech_bubble.dart';
import '../widgets/companion/pip_action_confirmation_banner.dart';
import '../widgets/companion/pip_ambient_glow.dart';
import '../widgets/companion/pip_stage_header.dart';
import '../widgets/pip_companion.dart';
import '../widgets/pocket_world/pip_pocket_world.dart';

/// The Pip tab: Pip on its island, its current line, what it's hearing, and
/// quick ways into the other screens. Instructions come from the shared
/// command bar in the app shell. No message history lives here.
class CompanionStageScreen extends StatefulWidget {
  /// True inside the wide (desktop) layout, where the rail handles navigation.
  final bool embedded;

  const CompanionStageScreen({super.key, this.embedded = false});

  @override
  State<CompanionStageScreen> createState() => _CompanionStageScreenState();
}

class _CompanionStageScreenState extends State<CompanionStageScreen> {
  /// Pip says something different each time it's poked, instead of one canned line.
  static const _tapLines = [
    "Hi! Tell me what you need, or tap Brief me to catch up.",
    "Boop! That tickles my sensors.",
    "Still here, still shiny. What's next?",
    "Need a hand? I have two. Well, grippers.",
  ];
  int _tapCount = 0;
  StreamSubscription<PipStageState>? _confirmListen;

  @override
  void initState() {
    super.initState();
    PipProfileService.userName().then((name) {
      // Greetings are Pip speaking up unprompted: only in casual mode.
      if (!mounted || name == null || !PresenceSettings.instance.allowProactive) return;
      context.read<PipStageCubit>().speak("${PipProfileService.greeting(name)} What are we tackling today?", isHappy: true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listenForConfirmations();
      _routeVoiceCommands();
    });
  }

  /// Once Pip finishes asking "shall I…?", open the mic for the answer, so a
  /// voice exchange stays hands-free (tap still works).
  void _listenForConfirmations() {
    final cubit = context.read<PipStageCubit>();
    var wasTyping = cubit.state.isTypewriting;
    _confirmListen = cubit.stream.listen((s) {
      final finishedAsking = wasTyping && !s.isTypewriting && s.pendingActionConfirmation != null;
      wasTyping = s.isTypewriting;
      final audio = getIt<PipAudioCoordinator>();
      if (finishedAsking && audio.isInitialized && !audio.isActiveListening) {
        audio.startActiveListening(onQuery: cubit.handleQuery);
      }
    });
  }

  /// Wake word and open-mic commands go to Pip with the current screen.
  void _routeVoiceCommands() {
    final cubit = context.read<PipStageCubit>();
    getIt<PipAudioCoordinator>().onCommandReceived = (query) =>
        cubit.state.isSleeping ? cubit.wakeUp() : cubit.handleQuery(PipScreenContext.withContext(query));
  }

  void _poke(PipStageCubit cubit, PipStageState state) {
    if (state.isSleeping) return cubit.wakeUp();
    cubit.speak(_tapLines[_tapCount++ % _tapLines.length], isHappy: true);
  }

  @override
  void dispose() {
    _confirmListen?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audio = getIt<PipAudioCoordinator>();
    final cubit = context.read<PipStageCubit>();
    return ListenableBuilder(
      listenable: audio,
      builder: (context, _) => BlocBuilder<PipStageCubit, PipStageState>(
        builder: (context, state) => Scaffold(
          backgroundColor: context.tokens.colors.background,
          body: PipPocketSky(
            child: Stack(children: [
              const PipAmbientGlow(),
              PipStageHeader(audioCoordinator: audio, showNavActions: !widget.embedded),
              SafeArea(
                child: Column(children: [
                  SizedBox(height: context.tokens.space.sm),
                  _SpeechLine(state: state, onDismiss: cubit.clearSpeechBubble, onRate: cubit.rateReply),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PipPocketIsland(
                          mood: audio.isActiveListening ? PipMood.listening : state.currentMood,
                          onTap: () => _poke(cubit, state),
                        ),
                      ),
                    ),
                  ),
                  const HeardCaption(),
                  if (state.pendingActionConfirmation != null)
                    PipActionConfirmationBanner(
                      confirmation: state.pendingActionConfirmation!,
                      onConfirm: cubit.confirmPendingAction,
                      onCancel: cubit.cancelPendingAction,
                    ).animate().fadeIn(duration: AppMotionTokens.resolveDuration(context, AppMotionTokens.fast))
                  else
                    const _HomeChips(),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Pip's one current line (replaced, never stacked into a history).
class _SpeechLine extends StatelessWidget {
  final PipStageState state;
  final VoidCallback onDismiss;
  final void Function({required bool positive}) onRate;

  const _SpeechLine({required this.state, required this.onDismiss, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (state.speechText.trim().isEmpty) return SizedBox(height: t.space.xxl);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.lg),
      child: ComicSpeechBubble(
        text: state.speechText,
        isStreaming: state.isTypewriting,
        onDismiss: onDismiss,
        onRate: (positive) => onRate(positive: positive),
      ),
    );
  }
}

/// Ways into the other screens; everything else is said to Pip.
class _HomeChips extends StatelessWidget {
  const _HomeChips();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l10n = context.l10n;
    final shell = StatefulNavigationShell.maybeOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.sm),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: t.space.sm,
        children: [
          ActionChip(
            avatar: const Icon(Icons.wb_sunny_outlined, size: 18),
            label: Text(l10n.chipBriefMe),
            onPressed: () => context.push(AppRoutes.briefing),
          ),
          ActionChip(
            avatar: const Icon(Icons.sports_esports_outlined, size: 18),
            label: Text(l10n.chipPlay),
            onPressed: () => context.push(AppRoutes.games),
          ),
          if (shell != null) ...[
            ActionChip(
              avatar: const Icon(Icons.checklist, size: 18),
              label: Text(l10n.navTasks),
              onPressed: () => shell.goBranch(1),
            ),
            ActionChip(
              avatar: const Icon(Icons.alarm, size: 18),
              label: Text(l10n.navAlarms),
              onPressed: () => shell.goBranch(2),
            ),
          ],
        ],
      ),
    );
  }
}
