import 'package:flutter/material.dart';
import '../core/services/pip_profile_service.dart';
import '../features/onboarding/onboarding_flow.dart';
import '../screens/pip_home_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/welcome_screen.dart';

enum _Stage { splash, welcome, onboarding, home }

/// Top-level flow: splash → (first run: welcome → onboarding) → home.
/// Stages cross-fade instead of stacking routes, so Back never returns to setup.
class PipAppFlow extends StatefulWidget {
  const PipAppFlow({super.key});

  @override
  State<PipAppFlow> createState() => _PipAppFlowState();
}

class _PipAppFlowState extends State<PipAppFlow> {
  _Stage _stage = _Stage.splash;
  bool _restored = false;
  late final Future<bool> _onboarded = PipProfileService.hasCompletedOnboarding();

  Future<void> _afterSplash() async {
    final done = await _onboarded;
    if (mounted) setState(() => _stage = done ? _Stage.home : _Stage.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = switch (_stage) {
      _Stage.splash => PipSplashScreen(onDone: _afterSplash),
      _Stage.welcome => PipWelcomeScreen(
          onStart: () => setState(() => _stage = _Stage.onboarding),
          onRestored: () => setState(() {
            _restored = true;
            _stage = _Stage.onboarding;
          }),
        ),
      _Stage.onboarding => OnboardingFlow(
          restoredFromBackup: _restored,
          onComplete: () => setState(() => _stage = _Stage.home),
        ),
      _Stage.home => const PipHomeScreen(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutCubic,
      child: KeyedSubtree(key: ValueKey(_stage), child: child),
    );
  }
}
