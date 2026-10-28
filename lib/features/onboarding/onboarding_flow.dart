import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/routes/app_routes.dart';
import '../../core/routes/onboarding_gate.dart';
import '../../core/services/pip_profile_service.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../core/theme/pip_theme.dart';
import '../../widgets/pip_guide.dart';
import '../../widgets/pip_params.dart';
import 'steps/backup_step.dart';
import 'steps/brain_step.dart';
import 'steps/connections_step.dart';
import 'steps/local_brain_step.dart';
import 'steps/name_step.dart';

/// What a step tells the flow: Pip's line and mood, and whether Continue is allowed.
class PipStepState {
  final String message;
  final PipMood mood;
  final bool canContinue;

  const PipStepState(this.message, {this.mood = PipMood.idle, this.canContinue = true});
}

/// Each step saves its own data when the user continues and returns false to
/// stay on the page (for example while a key is being tested).
abstract class OnboardingStepController {
  Future<bool> commit();
}

/// Pip-guided first-run setup: name → brain → backup → connections.
class OnboardingFlow extends StatefulWidget {
  /// True when the user restored a backup first, so Pip can say so.
  final bool restoredFromBackup;

  /// Run again from Settings: finishing goes back instead of to home.
  final bool rerun;

  const OnboardingFlow({super.key, this.restoredFromBackup = false, this.rerun = false});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const int _stepCount = 5;
  final PageController _pages = PageController();
  final List<GlobalKey> _keys = List.generate(_stepCount, (_) => GlobalKey());
  late final List<PipStepState> _states;
  int _index = 0;
  bool _busy = false;
  String? _name;

  @override
  void initState() {
    super.initState();
    _states = [
      PipStepState(
        widget.restoredFromBackup
            ? "Welcome back! Your memories are restored. What should I call you?"
            : "Hi! I'm Pip. What should I call you?",
        mood: PipMood.happy,
      ),
      const PipStepState('Pick a brain for me, paste its key, and tap Check key.'),
      const PipStepState("Want a private brain on this device too? It's optional and keeps downloading after you continue."),
      const PipStepState('Want a backup password? It locks your backups so only you can open them.'),
      const PipStepState('What should I help with? All optional, you can connect these later.'),
    ];
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _onStepChanged(int step, PipStepState state) {
    if (!mounted) return;
    setState(() => _states[step] = state);
  }

  Future<void> _next() async {
    final step = _keys[_index].currentState;
    if (step is OnboardingStepController) {
      final controller = step as OnboardingStepController;
      setState(() => _busy = true);
      final ok = await controller.commit();
      if (!mounted) return;
      setState(() => _busy = false);
      if (!ok) return;
    }
    if (_index == 0) _name = await PipProfileService.userName();
    if (_index == _stepCount - 1) {
      PipSfxService.happy();
      await OnboardingGate.instance.complete();
      if (!mounted) return;
      widget.rerun ? context.pop() : context.go(AppRoutes.home);
      return;
    }
    PipSfxService.chirp();
    _go(_index + 1);
  }

  void _go(int index) {
    setState(() => _index = index);
    _pages.animateToPage(
      index,
      duration: AppMotionTokens.resolveDuration(context, AppMotionTokens.medium),
      curve: AppMotionTokens.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _states[_index];
    // Greet by name only on the AI step's opening line, not on later reactions.
    final opening = _index == 1 && _name != null && state.message.startsWith('Pick a brain');
    final message = opening ? 'Nice to meet you, $_name! ${state.message}' : state.message;
    final isLast = _index == _stepCount - 1;

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(PipSpace.xl, PipSpace.lg, PipSpace.xl, 0),
          child: _Progress(index: _index, count: _stepCount),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PipSpace.lg, PipSpace.lg, PipSpace.xl, 0),
          child: PipGuide(message: message, mood: _busy ? PipMood.thinking : state.mood),
        ),
        Expanded(
          child: PageView(
            controller: _pages,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              NameStep(key: _keys[0], onState: (s) => _onStepChanged(0, s)),
              BrainStep(key: _keys[1], onState: (s) => _onStepChanged(1, s), onSkip: () => _go(2)),
              LocalBrainStep(key: _keys[2], onState: (s) => _onStepChanged(2, s)),
              BackupStep(key: _keys[3], onState: (s) => _onStepChanged(3, s)),
              ConnectionsStep(key: _keys[4], onState: (s) => _onStepChanged(4, s)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(PipSpace.xl, PipSpace.sm, PipSpace.xl, PipSpace.lg),
          child: Row(
            children: [
              if (_index > 0)
                Expanded(
                  child: OutlinedButton(onPressed: _busy ? null : () => _go(_index - 1), child: const Text('Back')),
                ),
              if (_index > 0) const SizedBox(width: PipSpace.sm),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy || !state.canContinue ? null : _next,
                  child: Text(_busy ? 'Checking…' : (isLast ? "Let's go" : 'Continue')),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          // On Windows and tablets the flow stays a comfortable column width.
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: body),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int index;
  final int count;

  const _Progress({required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(
        children: List.generate(count, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: EdgeInsets.only(right: i == count - 1 ? 0 : 6),
              decoration: BoxDecoration(
                color: i <= index ? PipColors.amber : PipColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
