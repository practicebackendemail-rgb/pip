import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import '../core/services/pip_desktop_window_manager.dart';
import '../core/theme/app_motion_tokens.dart';
import 'pip/pip_pose_controller.dart';
import 'pip_emote_painter.dart';
import 'pip_params.dart';
import 'pip_vector_painter.dart';

export 'pip_params.dart';

/// Pip, alive. One ticker steps a [PipPoseController] (spring physics) and
/// the painters repaint straight from it: no widget rebuilds per frame.
class PipDeskCompanion extends StatefulWidget {
  final PipMood mood;
  final double width;
  final double height;
  final VoidCallback? onTap;

  /// Where Pip looks, -1 (left) … 1 (right). Overrides idle glances when set.
  final double? gaze;

  /// Optional external controller, so a parent (the island) can feed travel
  /// speed and hops. When null the widget owns its own.
  final PipPoseController? controller;

  const PipDeskCompanion({
    super.key,
    this.mood = PipMood.idle,
    this.width = 310,
    this.height = 230,
    this.onTap,
    this.gaze,
    this.controller,
  });

  @override
  State<PipDeskCompanion> createState() => _PipDeskCompanionState();
}

class _PipDeskCompanionState extends State<PipDeskCompanion> with SingleTickerProviderStateMixin {
  late PipPoseController _controller;
  bool _ownsController = false;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _bindController();
    _ticker = createTicker(_onTick)..start();
  }

  void _bindController() {
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? PipPoseController();
    _controller
      ..mood = widget.mood
      ..gaze = widget.gaze;
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _controller.step(dt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.reduceMotion = AppMotionTokens.shouldReduceMotion(context);
  }

  @override
  void didUpdateWidget(covariant PipDeskCompanion old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _bindController();
    }
    _controller
      ..mood = widget.mood
      ..gaze = widget.gaze;
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _tap() {
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: PipVectorPainter.live(_controller.pose, repaint: _controller),
          foregroundPainter: PipEmotePainter(emote: emoteFor(widget.mood), pose: _controller.pose, repaint: _controller),
        ),
      ),
    );

    // Desktop pet: Pip itself catches the mouse, everything else clicks through.
    if (!kIsWeb && Platform.isWindows && PipDesktopWindowManager.isPetModeActive) {
      return MouseRegion(
        onEnter: (_) => PipDesktopWindowManager.setClickThrough(false),
        onExit: (_) => PipDesktopWindowManager.setClickThrough(true),
        child: GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
          onPanEnd: (_) => PipDesktopWindowManager.saveCurrentPosition(),
          onTap: widget.onTap,
          child: content,
        ),
      );
    }
    content = GestureDetector(onTap: widget.onTap == null ? null : _tap, child: content);
    return Semantics(label: 'Pip, ${widget.mood.name}', button: widget.onTap != null, child: content);
  }
}
