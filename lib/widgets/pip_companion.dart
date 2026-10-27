import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../core/services/pip_desktop_window_manager.dart';
import 'pip_emote_painter.dart';
import 'pip_params.dart';
import 'pip_vector_painter.dart';

export 'pip_params.dart';

class PipDeskCompanion extends StatefulWidget {
  final PipMood mood;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const PipDeskCompanion({
    super.key,
    this.mood = PipMood.idle,
    this.width = 310,
    this.height = 230,
    this.onTap,
  });

  @override
  State<PipDeskCompanion> createState() => _PipDeskCompanionState();
}

class _PipDeskCompanionState extends State<PipDeskCompanion> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  PipParams _current = PipParams.idle;
  PipParams _target = PipParams.idle;

  Timer? _blinkTimer;
  Timer? _lookTimer;
  Timer? _talkTimer;
  Timer? _fxTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(days: 365))
      ..addListener(_tick)
      ..forward();

    _applyMood(widget.mood);
    _scheduleBlink();
    _scheduleLookAround();
  }

  @override
  void didUpdateWidget(covariant PipDeskCompanion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood != widget.mood) {
      _applyMood(widget.mood);
    }
  }

  void _tick() {
    setState(() {
      _current = PipParams(
        lid: _lerp(_current.lid, _target.lid, 0.22),
        low: _lerp(_current.low, _target.low, 0.22),
        tilt: _lerp(_current.tilt, _target.tilt, 0.18),
        px: _lerp(_current.px, _target.px, 0.20),
        py: _lerp(_current.py, _target.py, 0.20),
        s: _lerp(_current.s, _target.s, 0.18),
        head: _lerp(_current.head, _target.head, 0.16),
        bob: _lerp(_current.bob, _target.bob, 0.25),
        al: _lerp(_current.al, _target.al, 0.18),
        ar: _lerp(_current.ar, _target.ar, 0.18),
        led: _target.led,
      );
    });
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  void _applyMood(PipMood mood) {
    _fxTimer?.cancel();
    _talkTimer?.cancel();

    switch (mood) {
      case PipMood.idle:
        _target = PipParams.idle;
        break;
      case PipMood.listening:
        _target = PipParams.listening;
        break;
      case PipMood.thinking:
        _target = PipParams.thinking;
        break;
      case PipMood.talking:
        _target = PipParams.talking;
        final rng = math.Random();
        _talkTimer = Timer.periodic(const Duration(milliseconds: 140), (t) {
          if (!mounted) return;
          setState(() {
            _target = PipParams.talking.copyWith(
              bob: (rng.nextDouble() * -7),
              s: 1.0 + (rng.nextDouble() * 0.08),
              px: (rng.nextDouble() - 0.5) * 0.8,
              py: (rng.nextDouble() - 0.5) * 0.8,
            );
          });
        });
        break;
      case PipMood.happy:
        _target = PipParams.happy;
        break;
      case PipMood.unsure:
        _target = PipParams.unsure;
        break;
      case PipMood.sleepy:
        _target = PipParams.sleepy;
        bool down = false;
        _fxTimer = Timer.periodic(const Duration(milliseconds: 1700), (t) {
          down = !down;
          setState(() {
            _target = PipParams.sleepy.copyWith(
              bob: down ? 4 : 0,
              lid: down ? 0.75 : 0.62,
            );
          });
        });
        break;
      case PipMood.sleeping:
        _target = PipParams.sleeping;
        bool snoring = false;
        _fxTimer = Timer.periodic(const Duration(milliseconds: 2200), (t) {
          snoring = !snoring;
          setState(() {
            _target = PipParams.sleeping.copyWith(
              bob: snoring ? 7 : 3,
              lid: snoring ? 0.98 : 0.92,
              s: snoring ? 0.96 : 0.93,
            );
          });
        });
        break;
      case PipMood.excited:
        _target = PipParams.excited;
        bool up = false;
        _fxTimer = Timer.periodic(const Duration(milliseconds: 260), (t) {
          up = !up;
          setState(() {
            _target = PipParams.excited.copyWith(bob: up ? -10 : 0);
          });
        });
        break;
      case PipMood.sad:
        _target = PipParams.sad;
        break;
      case PipMood.laughing:
        _target = PipParams.laughing;
        int step = 0;
        _fxTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
          step++;
          final b = (step % 2 == 0) ? -7.0 : 1.0;
          final armShift = (step % 2 == 0) ? 48.0 : 38.0;
          setState(() {
            _target = PipParams.laughing.copyWith(bob: b, al: armShift, ar: armShift);
          });
        });
        break;
      case PipMood.blinking:
        _target = _target.copyWith(lid: 1.0);
        Timer(const Duration(milliseconds: 160), () {
          if (!mounted) return;
          setState(() => _target = _target.copyWith(lid: 0.0));
          Timer(const Duration(milliseconds: 120), () {
            if (!mounted) return;
            setState(() => _target = _target.copyWith(lid: 1.0));
            Timer(const Duration(milliseconds: 160), () {
              if (!mounted) return;
              setState(() => _target = _target.copyWith(lid: 0.0));
            });
          });
        });
        break;
    }
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    final delay = 2200 + math.Random().nextInt(3200);
    _blinkTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted) return;
      final prevLid = _target.lid;
      setState(() => _target = _target.copyWith(lid: 1.0));
      Timer(const Duration(milliseconds: 130), () {
        if (!mounted) return;
        setState(() => _target = _target.copyWith(lid: prevLid));
        _scheduleBlink();
      });
    });
  }

  void _scheduleLookAround() {
    _lookTimer?.cancel();
    _lookTimer = Timer.periodic(const Duration(milliseconds: 2600), (t) {
      if (widget.mood == PipMood.idle && mounted) {
        final rng = math.Random();
        setState(() {
          _target = PipParams.idle.copyWith(
            px: (rng.nextDouble() - 0.5) * 2,
            py: (rng.nextDouble() - 0.5) * 1.2,
            head: (rng.nextDouble() - 0.5) * 6,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _lookTimer?.cancel();
    _talkTimer?.cancel();
    _fxTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final elapsed = _animController.lastElapsedDuration;
    final time = reduceMotion || elapsed == null ? 0.0 : elapsed.inMicroseconds / 1e6;
    Widget content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        foregroundPainter: PipEmotePainter(emote: emoteFor(widget.mood), time: time),
        painter: PipVectorPainter(
          time: time,
          talking: widget.mood == PipMood.talking && !reduceMotion,
          lid: _current.lid,
          low: _current.low,
          tilt: _current.tilt,
          px: _current.px,
          py: _current.py,
          s: _current.s,
          head: _current.head,
          bob: _current.bob,
          armLeftAngle: _current.al,
          armRightAngle: _current.ar,
          ledColor: _current.led,
        ),
      ),
    );

    // Step 8.2: Click-through toggle and dragging on desktop
    if (!kIsWeb && Platform.isWindows && PipDesktopWindowManager.isPetModeActive) {
      content = MouseRegion(
        onEnter: (_) => PipDesktopWindowManager.setClickThrough(false),
        onExit: (_) => PipDesktopWindowManager.setClickThrough(true),
        child: GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
          onPanEnd: (_) => PipDesktopWindowManager.saveCurrentPosition(),
          onTap: widget.onTap,
          child: content,
        ),
      );
    } else {
      content = Semantics(
        label: 'Pip, ${widget.mood.name}',
        button: widget.onTap != null,
        child: GestureDetector(
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  widget.onTap!();
                },
          child: content,
        ),
      );
    }

    return content;
  }
}
