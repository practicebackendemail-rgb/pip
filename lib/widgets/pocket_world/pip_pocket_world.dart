import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/services/pip_sfx_service.dart';
import '../../features/companion/domain/pip_idle_brain.dart';
import '../pip_companion.dart';
import 'pocket_island_painter.dart';
import 'pocket_sky_painter.dart';

/// One clock for the whole pocket world, so the sky's bird and Pip's eyes
/// agree on where things are.
final Stopwatch _worldClock = Stopwatch()..start();
double get _worldTime => _worldClock.elapsedMicroseconds / 1e6;
double get _localHour {
  final now = DateTime.now();
  return now.hour + now.minute / 60.0;
}

/// Full-screen sky behind the stage (replaces the old desk window scene).
class PipPocketSky extends StatefulWidget {
  final Widget child;
  final bool overcast;

  const PipPocketSky({super.key, required this.child, this.overcast = false});

  @override
  State<PipPocketSky> createState() => _PipPocketSkyState();
}

class _PipPocketSkyState extends State<PipPocketSky> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    // ~30 fps is plenty for drifting clouds and saves battery.
    var last = 0.0;
    _ticker = createTicker((_) {
      final t = _worldTime;
      if (t - last >= 1 / 30) {
        last = t;
        setState(() => _time = t);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PocketSkyPainter(hour: _localHour, time: still ? 0 : _time, overcast: widget.overcast),
            ),
          ),
        ),
        // Light scrim top and bottom so header and dock stay readable.
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                  stops: [0, .2, .62, 1],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Pip's floating island with Pip living on it. While [mood] is idle, Pip
/// does its own thing (see [PipIdleBrain]): rolls around, looks about,
/// watches birds, stretches, hops, waves, and naps after a long quiet spell.
/// Any other mood takes over immediately and Pip rolls back to the middle.
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
  late final Ticker _ticker;
  double _time = 0;

  double _x = .5; // left-right on the grass, 0..1
  double _y = .7; // depth on the grass, 0 = back, 1 = front
  double _fromX = .5;
  double _fromY = .7;
  bool _napping = false;
  PipIdleAction? _action;
  double _actionStart = 0;
  double _quietSince = 0;
  Timer? _next;

  bool get _idle => widget.mood == PipMood.idle;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _tick())..start();
    _schedule(const Duration(seconds: 3));
  }

  @override
  void didUpdateWidget(covariant PipPocketIsland old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      if (!_idle) {
        // Something is happening: stop the idle act and come front and centre.
        _next?.cancel();
        _napping = false;
        _startMove(.5, .85, null);
      } else {
        _quietSince = _worldTime;
        _schedule(const Duration(seconds: 4));
      }
    }
  }

  void _schedule(Duration after) {
    _next?.cancel();
    _next = Timer(after, () {
      if (!mounted || !_idle) return;
      final action = _brain.next(
        currentX: _x,
        currentY: _y,
        idleFor: Duration(milliseconds: ((_worldTime - _quietSince) * 1000).round()),
        hour: DateTime.now().hour,
      );
      _soundFor(action.kind);
      _startMove(action.targetX, action.targetY, action);
      _schedule(action.duration + Duration(milliseconds: 600 + math.Random().nextInt(2400)));
    });
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

  void _startMove(double tx, double ty, PipIdleAction? action) {
    _fromX = _x;
    _fromY = _y;
    _action = action ??
        PipIdleAction(PipIdleKind.wander, targetX: tx, targetY: ty, duration: const Duration(milliseconds: 1500));
    _actionStart = _worldTime;
  }

  void _tick() {
    final t = _worldTime;
    final a = _action;
    if (a != null && (a.targetX != _x || a.targetY != _y)) {
      // Every act may reposition Pip (wandering, coming forward to wave).
      final secs = a.kind == PipIdleKind.wander ? a.duration.inMilliseconds / 1000 : .8;
      final p = Curves.easeInOutSine.transform(((t - _actionStart) / secs).clamp(0.0, 1.0));
      _x = _fromX + (a.targetX - _fromX) * p;
      _y = _fromY + (a.targetY - _fromY) * p;
    }
    if (t - _time >= 1 / 30) setState(() => _time = t);
  }

  @override
  void dispose() {
    _next?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  /// Mood, gaze and hop height for this frame.
  (PipMood, double?, double) _pose() {
    if (!_idle) return (widget.mood, null, 0);
    final a = _action;
    if (a == null) return (PipMood.idle, null, 0);
    final elapsed = _time - _actionStart;
    final secs = a.duration.inMilliseconds / 1000;
    if (elapsed > secs) return (PipMood.idle, null, 0);
    switch (a.kind) {
      case PipIdleKind.wander:
        return (PipMood.idle, a.gaze, math.sin(elapsed * 9).abs() * 1.5); // little tread bumps
      case PipIdleKind.watchSky:
        final bird = PocketSkyPainter.birdAt(_time, const Size(1, 1), _localHour);
        final gaze = bird == null ? a.gaze : ((bird.dx - _x) * 2.2).clamp(-1.0, 1.0);
        return (a.mood, gaze, 0);
      case PipIdleKind.hop:
        final p = (elapsed / secs).clamp(0.0, 1.0);
        return (a.mood, 0, math.sin(p * math.pi) * 26);
      case PipIdleKind.lookAround:
        return (a.mood, elapsed < secs / 2 ? a.gaze : -a.gaze, 0);
      default:
        return (a.mood, a.gaze == 0 ? null : a.gaze, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return LayoutBuilder(builder: (context, c) {
      // The island fills the width and Pip is drawn large: a close-up camera.
      final available = c.maxWidth.isFinite ? c.maxWidth : widget.maxWidth;
      final islandW = math.min(available, widget.maxWidth);
      final scale = islandW / PocketIslandPainter.width;
      final islandH = PocketIslandPainter.height * scale;
      final pipBaseW = islandW * .48;
      final totalH = islandH + pipBaseW * .75 * .7;
      final islandTop = totalH - islandH;
      final float = still ? 0.0 : math.sin(_time * .8) * 5;

      final (mood, gaze, hop) = still ? (widget.mood, null, 0.0) : _pose();
      final x = still ? .5 : _x;
      final y = still ? .85 : _y;
      // Further back = a little smaller, for depth.
      final depthScale = .82 + .2 * y;
      final pipW = pipBaseW * depthScale;
      final pipH = pipW * .75;
      final surfaceX = (PocketIslandPainter.minX + x * (PocketIslandPainter.maxX - PocketIslandPainter.minX)) * scale;
      final feetY =
          islandTop + (PocketIslandPainter.backY + y * (PocketIslandPainter.frontY - PocketIslandPainter.backY)) * scale;

      return SizedBox(
        width: islandW,
        height: totalH,
        child: Transform.translate(
          offset: Offset(0, float),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: islandTop,
                width: islandW,
                height: islandH,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: PocketIslandPainter(time: still ? 0 : _time, night: PocketSkyPainter.nightness(_localHour)),
                  ),
                ),
              ),
              // Contact shadow shrinks while Pip is in the air.
              Positioned(
                left: surfaceX - pipW * .32,
                top: feetY - 6,
                width: pipW * .64,
                height: 10,
                child: Opacity(
                  opacity: (.3 - hop / 120).clamp(.08, .3),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.all(Radius.elliptical(60, 6))),
                  ),
                ),
              ),
              Positioned(
                left: surfaceX - pipW / 2,
                top: feetY - pipH * .96 - hop,
                child: PipDeskCompanion(mood: mood, gaze: gaze, width: pipW, height: pipH, onTap: widget.onTap),
              ),
            ],
          ),
        ),
      );
    });
  }
}
