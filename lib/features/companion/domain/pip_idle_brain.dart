import 'dart:math' as math;
import '../../../widgets/pip_params.dart';

enum PipIdleKind { wander, lookAround, watchSky, stretch, hop, wave, nap }

/// One thing Pip does on its own: where to roll to (0 = left edge of the
/// island, 1 = right edge), which way to look, how long it lasts, and the
/// mood to show meanwhile.
class PipIdleAction {
  final PipIdleKind kind;
  final double targetX;

  /// Depth on the island: 0 = far edge (back), 1 = near edge (front).
  final double targetY;
  final double gaze; // -1 left … 1 right
  final Duration duration;
  final PipMood mood;

  const PipIdleAction(
    this.kind, {
    required this.targetX,
    this.targetY = .5,
    this.gaze = 0,
    required this.duration,
    this.mood = PipMood.idle,
  });
}

/// Picks Pip's next idle action. Pure logic with an injectable [math.Random]
/// so behaviour is testable and deterministic under a seed.
///
/// Rules: never repeat the same action twice in a row (except wandering),
/// nap only after a long quiet spell, and nap more at night.
class PipIdleBrain {
  final math.Random _rng;
  PipIdleKind? _last;

  PipIdleBrain([math.Random? rng]) : _rng = rng ?? math.Random();

  PipIdleAction next({required double currentX, double currentY = .5, required Duration idleFor, required int hour}) {
    final night = hour >= 22 || hour < 6;
    final sleepy = idleFor > const Duration(minutes: 2);

    final weights = <PipIdleKind, double>{
      PipIdleKind.wander: 4,
      PipIdleKind.lookAround: 3,
      PipIdleKind.watchSky: 2,
      PipIdleKind.stretch: 1.2,
      PipIdleKind.hop: night ? 0.3 : 1.2,
      PipIdleKind.wave: 0.8,
      PipIdleKind.nap: sleepy ? (night ? 5 : 1.5) : 0,
    };
    if (_last != null && _last != PipIdleKind.wander) weights[_last!] = 0;

    final kind = _pick(weights);
    _last = kind;
    return _build(kind, currentX, currentY);
  }

  PipIdleKind _pick(Map<PipIdleKind, double> weights) {
    final total = weights.values.fold(0.0, (a, b) => a + b);
    var r = _rng.nextDouble() * total;
    for (final e in weights.entries) {
      r -= e.value;
      if (r <= 0 && e.value > 0) return e.key;
    }
    return PipIdleKind.lookAround;
  }

  double _between(double a, double b) => a + _rng.nextDouble() * (b - a);
  Duration _secs(double a, double b) => Duration(milliseconds: (_between(a, b) * 1000).round());

  PipIdleAction _build(PipIdleKind kind, double x, double y) {
    switch (kind) {
      case PipIdleKind.wander:
        // Roll somewhere noticeably different across the whole island,
        // left-right and front-back.
        var tx = _between(0.05, 0.95);
        final ty = _between(0, 1);
        if ((tx - x).abs() + (ty - y).abs() < 0.35) tx = x < 0.5 ? x + 0.4 : x - 0.4;
        tx = tx.clamp(0.05, 0.95);
        final distance = (tx - x).abs() + (ty - y).abs() * .5;
        return PipIdleAction(
          kind,
          targetX: tx,
          targetY: ty,
          gaze: (tx - x).abs() < .05 ? 0 : (tx - x).sign,
          duration: Duration(milliseconds: (1800 + distance * 3200).round()),
        );
      case PipIdleKind.lookAround:
        return PipIdleAction(kind, targetX: x, targetY: y, gaze: _rng.nextBool() ? -1 : 1, duration: _secs(2, 3.5));
      case PipIdleKind.watchSky:
        return PipIdleAction(kind,
            targetX: x, targetY: y, gaze: _between(-.6, .6), duration: _secs(3, 5), mood: PipMood.listening);
      case PipIdleKind.stretch:
        return PipIdleAction(kind, targetX: x, targetY: y, duration: _secs(1.6, 2.4), mood: PipMood.excited);
      case PipIdleKind.hop:
        return PipIdleAction(kind,
            targetX: x, targetY: y, duration: const Duration(milliseconds: 900), mood: PipMood.happy);
      case PipIdleKind.wave:
        // Comes to the front to wave at you.
        return PipIdleAction(kind, targetX: x, targetY: 1, gaze: 0, duration: _secs(1.8, 2.6), mood: PipMood.happy);
      case PipIdleKind.nap:
        return PipIdleAction(kind, targetX: x, targetY: y, duration: _secs(20, 40), mood: PipMood.sleepy);
    }
  }
}
