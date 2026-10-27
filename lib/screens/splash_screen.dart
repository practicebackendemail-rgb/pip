import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/pip_theme.dart';
import '../widgets/pip_companion.dart';

/// Pip "boots up": asleep, eyes open, a happy bounce, then [onDone].
/// Kept under 1.6 s (instant-ish with reduced motion) so it never feels like a wait.
class PipSplashScreen extends StatefulWidget {
  final VoidCallback onDone;

  const PipSplashScreen({super.key, required this.onDone});

  @override
  State<PipSplashScreen> createState() => _PipSplashScreenState();
}

class _PipSplashScreenState extends State<PipSplashScreen> {
  PipMood _mood = PipMood.sleeping;
  final List<Timer> _timers = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_timers.isNotEmpty) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _mood = PipMood.idle;
      _timers.add(Timer(const Duration(milliseconds: 400), widget.onDone));
      return;
    }
    _timers
      ..add(Timer(const Duration(milliseconds: 450), () => _set(PipMood.idle)))
      ..add(Timer(const Duration(milliseconds: 850), () => _set(PipMood.excited)))
      ..add(Timer(const Duration(milliseconds: 1550), widget.onDone));
  }

  void _set(PipMood mood) {
    if (mounted) setState(() => _mood = mood);
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final awake = _mood != PipMood.sleeping;
    return Scaffold(
      backgroundColor: PipColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PipDeskCompanion(mood: _mood, width: 200, height: 150),
            const SizedBox(height: PipSpace.xl),
            AnimatedOpacity(
              opacity: awake ? 1 : 0.35,
              duration: const Duration(milliseconds: 400),
              child: const Text(
                'PIP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                  color: PipColors.amber,
                ),
              ),
            ),
            const SizedBox(height: PipSpace.sm),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                awake ? 'Ready when you are' : 'Waking up…',
                key: ValueKey(awake),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
