import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_assistant/features/companion/domain/pip_spring.dart';
import 'package:personal_assistant/widgets/pip/pip_pose_controller.dart';
import 'package:personal_assistant/widgets/pip_params.dart';

void run(void Function(double) step, {required int hz, required double seconds}) {
  for (var i = 0; i < (hz * seconds).round(); i++) {
    step(1 / hz);
  }
}

void main() {
  group('Spring', () {
    test('settles on its target', () {
      final s = PipSpring(0, spec: SpringSpec.lively)..target = 1;
      run(s.step, hz: 60, seconds: 2);
      expect(s.value, closeTo(1, 1e-3));
      expect(s.isSettled, isTrue);
    });

    test('looks the same at 60 Hz and 120 Hz (frame-rate independent)', () {
      final a = PipSpring(0, spec: SpringSpec.bouncy)..target = 1;
      final b = PipSpring(0, spec: SpringSpec.bouncy)..target = 1;
      run(a.step, hz: 60, seconds: .3);
      run(b.step, hz: 120, seconds: .3);
      expect(a.value, closeTo(b.value, .01));
    });

    test('a long stall does not explode', () {
      final s = PipSpring(0, spec: SpringSpec.snappy)..target = 1;
      s.step(5);
      expect(s.value.isFinite, isTrue);
      expect(s.value, closeTo(1, .05));
    });

    test('bouncy springs overshoot, critically damped ones do not', () {
      double peak(SpringSpec spec) {
        final s = PipSpring(0, spec: spec)..target = 1;
        var max = 0.0;
        for (var i = 0; i < 240; i++) {
          s.step(1 / 120);
          max = math.max(max, s.value);
        }
        return max;
      }

      expect(peak(SpringSpec.bouncy), greaterThan(1.02));
      expect(peak(SpringSpec.snappy), lessThanOrEqualTo(1.0001));
    });
  });

  group('Pose controller', () {
    PipPoseController make() => PipPoseController(random: math.Random(1));

    test('a mood drives the pose toward its parameters', () {
      final c = make()..mood = PipMood.happy;
      run(c.step, hz: 60, seconds: 1.5);
      expect(c.pose.armLeft, closeTo(PipParams.happy.al, 3));
      expect(c.pose.low, closeTo(PipParams.happy.low, .05));
      expect(c.pose.led, PipParams.happy.led);
    });

    test('blinks on its own every few seconds', () {
      final c = make();
      var closed = false;
      for (var i = 0; i < 60 * 8; i++) {
        c.step(1 / 60);
        if (c.pose.lid > .8) closed = true;
      }
      expect(closed, isTrue);
    });

    test('rolling right leans the body and spins the wheels; stopping recovers', () {
      final c = make()..travelVelocity = .3;
      run(c.step, hz: 60, seconds: .6);
      expect(c.pose.lean, lessThan(-1));
      expect(c.pose.treadPhase, greaterThan(0));
      c.travelVelocity = 0;
      run(c.step, hz: 60, seconds: 3);
      expect(c.pose.lean.abs(), lessThan(.2));
    });

    test('landing squashes and springs back', () {
      final c = make()..land();
      var minSquash = 1.0;
      for (var i = 0; i < 30; i++) {
        c.step(1 / 60);
        minSquash = math.min(minSquash, c.pose.squash);
      }
      expect(minSquash, lessThan(.97));
      run(c.step, hz: 60, seconds: 2);
      expect(c.pose.squash, closeTo(1, .01));
    });

    test('reduce motion jumps straight to the pose with no wobble', () {
      final c = make()..reduceMotion = true;
      c.mood = PipMood.excited;
      c.step(1 / 60);
      expect(c.pose.armLeft, PipParams.excited.al);
      expect(c.pose.talking, isFalse);
    });

    test('gaze overrides idle glances', () {
      final c = make()..gaze = -1;
      run(c.step, hz: 60, seconds: 1.5);
      expect(c.pose.px, closeTo(-1, .05));
    });
  });
}
