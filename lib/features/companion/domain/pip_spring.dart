import 'dart:math' as math;

/// How a spring feels: [stiffness] sets speed, [damping] sets overshoot.
/// Damping ratio 1 = critically damped (fast, no wobble); below 1 wobbles.
class SpringSpec {
  final double stiffness;
  final double dampingRatio;

  const SpringSpec({required this.stiffness, this.dampingRatio = 1});

  double get damping => 2 * dampingRatio * math.sqrt(stiffness);

  /// Eyelids and blinks: very fast, no wobble.
  static const snappy = SpringSpec(stiffness: 900);

  /// Gaze, head and pupils: quick with a hint of overshoot.
  static const lively = SpringSpec(stiffness: 260, dampingRatio: .72);

  /// Arms and body: softer, visible follow-through.
  static const bouncy = SpringSpec(stiffness: 140, dampingRatio: .55);

  /// Rolling across the island: heavy, settles without bouncing.
  static const travel = SpringSpec(stiffness: 18, dampingRatio: .95);
}

/// A 1-D damped spring stepped by real elapsed time, so motion looks the
/// same at 60 Hz and 120 Hz (unlike "move 22% per frame" lerps).
class PipSpring {
  double value;
  double velocity = 0;
  double target;
  SpringSpec spec;

  PipSpring(double initial, {this.spec = SpringSpec.lively})
      : value = initial,
        target = initial;

  /// Largest step integrated at once; long frames are split into these so a
  /// stall (app resumed, debugger) can't make the spring explode.
  static const double _maxStep = 1 / 120;

  void step(double dt) {
    var remaining = dt.clamp(0, .25);
    while (remaining > 0) {
      final h = math.min(remaining, _maxStep);
      // Semi-implicit Euler: stable for stiff springs at these step sizes.
      final accel = -spec.stiffness * (value - target) - spec.damping * velocity;
      velocity += accel * h;
      value += velocity * h;
      remaining -= h;
    }
  }

  /// Jumps straight to [v] with no motion (reduce motion, first frame).
  void snap(double v) {
    value = v;
    target = v;
    velocity = 0;
  }

  /// Adds an instant kick, e.g. a hop's take-off or a landing squash.
  void impulse(double dv) => velocity += dv;

  bool get isSettled => (value - target).abs() < 1e-3 && velocity.abs() < 1e-3;
}
