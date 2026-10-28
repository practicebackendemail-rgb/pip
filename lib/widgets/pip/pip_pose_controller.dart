import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import '../../features/companion/domain/pip_spring.dart';
import '../pip_params.dart';
import 'pip_pose.dart';

/// Drives Pip's pose with springs and a single clock. Moods set spring
/// targets; small behaviours (blink, glance, talk jitter, sway, bounce) are
/// scheduled on elapsed time instead of separate timers. Call [step] once per
/// frame; it updates [pose] in place and notifies the painter.
class PipPoseController extends ChangeNotifier {
  PipPoseController({math.Random? random}) : _rng = random ?? math.Random() {
    _apply(PipMood.idle, snap: true);
  }

  final math.Random _rng;
  final PipPose pose = PipPose();

  final _lid = PipSpring(0, spec: SpringSpec.snappy);
  final _low = PipSpring(0, spec: SpringSpec.snappy);
  final _tilt = PipSpring(14);
  final _px = PipSpring(0);
  final _py = PipSpring(0);
  final _s = PipSpring(1);
  final _head = PipSpring(0);
  final _bob = PipSpring(0, spec: SpringSpec.bouncy);
  final _armL = PipSpring(3, spec: SpringSpec.bouncy);
  final _armR = PipSpring(3, spec: SpringSpec.bouncy);
  final _lean = PipSpring(0, spec: SpringSpec.bouncy);
  final _squash = PipSpring(1, spec: const SpringSpec(stiffness: 320, dampingRatio: .35));

  PipMood _mood = PipMood.idle;
  PipParams _base = PipParams.idle;
  double _t = 0;
  double _nextBlink = 2.5, _blinkEnd = -1;
  double _nextGlance = 2.6, _nextBeat = 0;
  bool _beat = false;
  double _travelVelocity = 0;

  /// Where Pip looks (-1 … 1), overriding idle glances; null to let it roam.
  double? gaze;

  /// When true, poses jump without motion and idle behaviours stop.
  bool reduceMotion = false;

  PipMood get mood => _mood;

  set mood(PipMood m) {
    if (m == _mood) return;
    _mood = m;
    _apply(m, snap: reduceMotion);
  }

  /// Rolling speed in island widths per second; drives lean and the wheels.
  set travelVelocity(double v) => _travelVelocity = v;

  /// Take-off: a quick stretch.
  void hop() => _squash.impulse(4);

  /// Touch-down: a squash that springs back.
  void land() => _squash.impulse(-5);

  static PipParams paramsFor(PipMood m) => switch (m) {
        PipMood.listening => PipParams.listening,
        PipMood.thinking => PipParams.thinking,
        PipMood.talking => PipParams.talking,
        PipMood.happy => PipParams.happy,
        PipMood.unsure => PipParams.unsure,
        PipMood.sleepy => PipParams.sleepy,
        PipMood.sleeping => PipParams.sleeping,
        PipMood.excited => PipParams.excited,
        PipMood.sad => PipParams.sad,
        PipMood.laughing => PipParams.laughing,
        _ => PipParams.idle,
      };

  void _apply(PipMood m, {required bool snap}) {
    _base = paramsFor(m);
    _setTargets(_base, snap: snap);
    pose.led = _base.led;
    if (m == PipMood.blinking) _blinkEnd = _t + .5; // a double blink
  }

  void _setTargets(PipParams p, {bool snap = false}) {
    void set(PipSpring s, double v) => snap ? s.snap(v) : s.target = v;
    set(_lid, p.lid);
    set(_low, p.low);
    set(_tilt, p.tilt);
    set(_px, p.px);
    set(_py, p.py);
    set(_s, p.s);
    set(_head, p.head);
    set(_bob, p.bob);
    set(_armL, p.al);
    set(_armR, p.ar);
  }

  /// Advances everything by [dt] seconds and repaints.
  void step(double dt) {
    _t += dt;
    if (!reduceMotion) _behaviours();
    final springs = [_lid, _low, _tilt, _px, _py, _s, _head, _bob, _armL, _armR, _lean, _squash];
    for (final s in springs) {
      reduceMotion ? s.snap(s.target) : s.step(dt);
    }
    _lean.target = (-_travelVelocity * 18).clamp(-9.0, 9.0);
    pose
      ..lid = _lid.value.clamp(0.0, 1.0)
      ..low = _low.value.clamp(0.0, 1.0)
      ..tilt = _tilt.value
      ..px = _px.value
      ..py = _py.value
      ..s = _s.value
      ..head = _head.value
      ..bob = _bob.value
      ..armLeft = _armL.value
      ..armRight = _armR.value
      ..lean = _lean.value
      ..squash = _squash.value.clamp(.82, 1.18)
      ..treadPhase = pose.treadPhase + _travelVelocity * dt * 40
      ..time = _t
      ..talking = _mood == PipMood.talking && !reduceMotion;
    notifyListeners();
  }

  double _between(double a, double b) => a + _rng.nextDouble() * (b - a);

  void _behaviours() {
    _blink();
    if (gaze != null) {
      _px.target = gaze!;
    } else if (_mood == PipMood.idle && _t >= _nextGlance) {
      _nextGlance = _t + 2.6;
      _px.target = _between(-1, 1);
      _py.target = _between(-.6, .6);
      _head.target = _between(-3, 3);
    }
    _rhythm();
  }

  void _blink() {
    final asleep = _mood == PipMood.sleeping;
    if (!asleep && _t >= _nextBlink) {
      _blinkEnd = _t + .13;
      _nextBlink = _t + _between(2.2, 5.4);
    }
    _lid.target = _t < _blinkEnd ? 1 : _base.lid;
  }

  /// Mood-specific repeating motion: talk jitter, sway, bounce, laugh.
  void _rhythm() {
    final period = switch (_mood) {
      PipMood.talking => .14,
      PipMood.sleepy => 1.7,
      PipMood.sleeping => 2.2,
      PipMood.excited => .26,
      PipMood.laughing => .12,
      _ => 0.0,
    };
    if (period == 0 || _t < _nextBeat) return;
    _nextBeat = _t + period;
    _beat = !_beat;
    switch (_mood) {
      case PipMood.talking:
        _bob.target = _between(-7, 0);
        _s.target = 1 + _between(0, .08);
        _px.target = gaze ?? _between(-.4, .4);
        _py.target = _between(-.4, .4);
      case PipMood.sleepy:
        _bob.target = _beat ? 4 : 0;
        _base = _base.copyWith(lid: _beat ? .75 : .62);
      case PipMood.sleeping:
        _bob.target = _beat ? 7 : 3;
        _s.target = _beat ? .96 : .93;
        _base = _base.copyWith(lid: _beat ? .98 : .92);
      case PipMood.excited:
        _bob.target = _beat ? -10 : 0;
      case PipMood.laughing:
        _bob.target = _beat ? -7 : 1;
        _armL.target = _armR.target = _beat ? 48 : 38;
      default:
        break;
    }
  }

  @visibleForTesting
  Color get ledColor => pose.led;
}
