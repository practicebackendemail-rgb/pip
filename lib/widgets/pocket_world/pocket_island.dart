import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../core/theme/app_motion_tokens.dart';
import '../../features/companion/domain/pip_idle_brain.dart';
import '../../features/companion/domain/pip_spring.dart';
import '../pip/pip_pose_controller.dart';
import '../pip_companion.dart';
import 'pip_pocket_world.dart';
import 'pocket_island_painter.dart';
import 'pocket_sky_painter.dart';

/// Pip's floating island with Pip living on it. While [mood] is idle, Pip
/// does its own thing (see [PipIdleBrain]); any other mood takes over and Pip
/// rolls front and centre. Motion is physical: position on heavy springs,
/// lean and wheel spin from speed, a ballistic hop with squash on landing.
class PipPocketIsland extends StatefulWidget {
  final PipMood mood;
  final VoidCallback? onTap;
  final double maxWidth;

  const PipPocketIsland({super.key, required this.mood, this.onTap, this.maxWidth = 560});

  @override
  State<PipPocketIsland> createState() => _PipPocketIslandState();
}

class _PipPocketIslandState extends State<PipPocketIsland> with SingleTickerProviderStateMixin {
  final PipIdleBrain _brain = PipIdleBrain();
  final PipPoseController _pip = PipPoseController();
  final _x = PipSpring(.5, spec: SpringSpec.travel); // left-right on the grass, 0..1
  final _y = PipSpring(.85, spec: SpringSpec.travel); // depth, 0 = back, 1 = front
  final ValueNotifier<double> _frame = ValueNotifier(0); // repaint signal for the moving layer
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _hopHeight = 0, _hopVelocity = 0; // in Pip heights; > 0 while airborne
  static const double _gravity = 14, _hopLaunch = 2.4;

  PipIdleAction? _action;
  double _actionStart = 0, _quietSince = 0;
  bool _napping = false;
  Timer? _next;

  bool get _idle => widget.mood == PipMood.idle;
  bool get _still => AppMotionTokens.shouldReduceMotion(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _schedule(const Duration(seconds: 3));
  }

  @override
  void didUpdateWidget(covariant PipPocketIsland old) {
    super.didUpdateWidget(old);
    if (old.mood == widget.mood) return;
    if (!_idle) {
      // Something is happening: stop the idle act and come front and centre.
      _next?.cancel();
      _napping = false;
      _action = null;
      _x.target = .5;
      _y.target = .85;
    } else {
      _quietSince = pocketWorldTime;
      _schedule(const Duration(seconds: 4));
    }
  }

  void _schedule(Duration after) {
    _next?.cancel();
    _next = Timer(after, () {
      if (!mounted || !_idle) return;
      final action = _brain.next(
        currentX: _x.target,
        currentY: _y.target,
        idleFor: Duration(milliseconds: ((pocketWorldTime - _quietSince) * 1000).round()),
        hour: DateTime.now().hour,
      );
      _start(action);
      _schedule(action.duration + Duration(milliseconds: 600 + math.Random().nextInt(2400)));
    });
  }

  void _start(PipIdleAction action) {
    _soundFor(action.kind);
    _action = action;
    _actionStart = pocketWorldTime;
    _x.target = action.targetX;
    _y.target = action.targetY;
    if (action.kind == PipIdleKind.hop && _hopHeight == 0) {
      _hopVelocity = _hopLaunch;
      _pip.hop();
    }
  }

  /// Little noises for Pip's own acts, softer than replies and quiet at night.
  void _soundFor(PipIdleKind kind) {
    if (_napping && kind != PipIdleKind.nap) PipSfxService.idle(PipSound.chirp); // waking up
    _napping = kind == PipIdleKind.nap;
    switch (kind) {
      case PipIdleKind.hop:
        PipSfxService.idle(PipSound.blip);
      case PipIdleKind.wave:
      case PipIdleKind.stretch:
        PipSfxService.idle(PipSound.happy);
      case PipIdleKind.nap:
        PipSfxService.idle(PipSound.sleep);
      case PipIdleKind.watchSky:
        PipSfxService.idle(PipSound.chirp);
      default:
        break;
    }
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (_still) {
      _x.snap(.5);
      _y.snap(.85);
    } else {
      _x.step(dt);
      _y.step(dt);
      _stepHop(dt);
    }
    final (mood, gaze) = _moodAndGaze();
    _pip
      ..mood = mood
      ..gaze = gaze
      ..travelVelocity = _x.velocity;
    _frame.value = pocketWorldTime;
  }

  void _stepHop(double dt) {
    if (_hopHeight <= 0 && _hopVelocity <= 0) return;
    _hopVelocity -= _gravity * dt;
    _hopHeight += _hopVelocity * dt;
    if (_hopHeight <= 0) {
      _hopHeight = 0;
      _hopVelocity = 0;
      _pip.land();
    }
  }

  (PipMood, double?) _moodAndGaze() {
    if (!_idle) return (widget.mood, null);
    final a = _action;
    final elapsed = pocketWorldTime - _actionStart;
    if (a == null || elapsed > a.duration.inMilliseconds / 1000) return (PipMood.idle, null);
    switch (a.kind) {
      case PipIdleKind.wander:
        return (PipMood.idle, (_x.velocity * 6).clamp(-1.0, 1.0)); // look where it's going
      case PipIdleKind.watchSky:
        final bird = PocketSkyPainter.birdAt(pocketWorldTime, const Size(1, 1), pocketLocalHour);
        return (a.mood, bird == null ? a.gaze : ((bird.dx - _x.value) * 2.2).clamp(-1.0, 1.0));
      case PipIdleKind.lookAround:
        return (a.mood, elapsed < a.duration.inMilliseconds / 2000 ? a.gaze : -a.gaze);
      default:
        return (a.mood, a.gaze == 0 ? null : a.gaze);
    }
  }

  @override
  void dispose() {
    _next?.cancel();
    _ticker.dispose();
    _frame.dispose();
    _pip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final available = c.maxWidth.isFinite ? c.maxWidth : widget.maxWidth;
      final g = _IslandGeometry(math.min(available, widget.maxWidth));
      return SizedBox(
        width: g.islandW,
        height: g.totalH,
        child: ValueListenableBuilder<double>(
          valueListenable: _frame,
          builder: (context, time, _) => _layer(g, _still ? 0 : time),
        ),
      );
    });
  }

  Widget _layer(_IslandGeometry g, double time) {
    final y = _y.value;
    final pipW = g.pipBaseW * (.82 + .2 * y); // further back = a little smaller
    final pipH = pipW * .75;
    final surfaceX = g.surfaceX(_x.value);
    final feetY = g.feetY(y);
    final lift = _hopHeight * pipH;
    return Transform.translate(
      offset: Offset(0, math.sin(time * .8) * 5), // the island floats
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          left: 0,
          top: g.islandTop,
          width: g.islandW,
          height: g.islandH,
          child: RepaintBoundary(
            child: CustomPaint(painter: PocketIslandPainter(time: time, night: PocketSkyPainter.nightness(pocketLocalHour))),
          ),
        ),
        Positioned(
          left: surfaceX - pipW * .32,
          top: feetY - 6,
          width: pipW * .64,
          height: 10,
          child: Opacity(
            opacity: (.3 - _hopHeight * .5).clamp(.08, .3), // shadow fades while airborne
            child: const DecoratedBox(
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.elliptical(60, 6))),
            ),
          ),
        ),
        Positioned(
          left: surfaceX - pipW / 2,
          top: feetY - pipH * .96 - lift,
          child: PipDeskCompanion(controller: _pip, mood: _pip.mood, gaze: _pip.gaze, width: pipW, height: pipH, onTap: widget.onTap),
        ),
      ]),
    );
  }
}

/// Sizes derived from the island's width (a close-up camera: island fills
/// the width, Pip is large).
class _IslandGeometry {
  final double islandW;
  _IslandGeometry(this.islandW);

  double get scale => islandW / PocketIslandPainter.width;
  double get islandH => PocketIslandPainter.height * scale;
  double get pipBaseW => islandW * .48;
  double get totalH => islandH + pipBaseW * .75 * .7;
  double get islandTop => totalH - islandH;

  double surfaceX(double x) =>
      (PocketIslandPainter.minX + x * (PocketIslandPainter.maxX - PocketIslandPainter.minX)) * scale;

  double feetY(double y) =>
      islandTop + (PocketIslandPainter.backY + y * (PocketIslandPainter.frontY - PocketIslandPainter.backY)) * scale;
}
