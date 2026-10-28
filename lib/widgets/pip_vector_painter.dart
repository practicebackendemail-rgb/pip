import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pip/pip_eye_painter.dart';
import 'pip/pip_paints.dart';
import 'pip/pip_pose.dart';

export 'pip/pip_pose.dart';

/// Pip, drawn from the design blueprint in a 320 x 240 space.
///
/// Live use: pass a [PipPose] that a controller mutates plus that
/// controller as [repaint]; frames then repaint without rebuilding widgets.
/// The named-parameter constructor draws a fixed pose (overlay, tests).
class PipVectorPainter extends CustomPainter {
  final PipPose pose;

  PipVectorPainter.live(this.pose, {super.repaint});

  PipVectorPainter({
    double time = 0,
    bool talking = false,
    double lid = 0,
    double low = 0,
    double tilt = 14,
    double px = 0,
    double py = 0,
    double s = 1.0,
    double head = 0,
    double bob = 0,
    double armLeftAngle = 3,
    double armRightAngle = 3,
    Color ledColor = const Color(0xFF6FBF73),
  }) : pose = PipPose(
          time: time,
          talking: talking,
          lid: lid,
          low: low,
          tilt: tilt,
          px: px,
          py: py,
          s: s,
          head: head,
          bob: bob,
          armLeft: armLeftAngle,
          armRight: armRightAngle,
          led: ledColor,
        );

  static const double _w = 320, _h = 240;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    canvas.save();
    canvas.scale(size.width / _w);

    canvas.drawOval(PipPaints.shadowLeft, PipPaints.shadowLeftPaint);
    canvas.drawOval(PipPaints.shadowRight, PipPaints.shadowRightPaint);
    canvas.drawOval(PipPaints.shadowMid, PipPaints.shadowMidPaint);

    // Squash/stretch from the feet, and lean around the base while rolling.
    canvas.translate(_w / 2, _h - 8);
    canvas.rotate(p.lean * math.pi / 180);
    canvas.scale(2 - p.squash, p.squash);
    canvas.translate(-_w / 2, -(_h - 8));

    _track(canvas, 36, p.treadPhase);
    _track(canvas, 232, p.treadPhase);
    _arm(canvas, 56, p.armLeft, true);
    _arm(canvas, 226, p.armRight, false);
    _torso(canvas);
    _chest(canvas, p);
    _head(canvas, p);
    canvas.restore();
  }

  void _track(Canvas canvas, double x, double phase) {
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 140, 52, 92), const Radius.circular(14)), PipPaints.trackFill);
    // Ribs scroll with the wheels so rolling reads as rolling.
    final shift = (phase * 8 / math.pi) % 10;
    for (double y = 145 + shift; y < 227; y += 10) {
      canvas.drawLine(Offset(x + 7, y), Offset(x + 45, y), PipPaints.ribStroke);
    }
    for (final hy in const [158.0, 214.0]) {
      final c = Offset(x + 26, hy);
      canvas.drawCircle(c, 8, PipPaints.hubFill);
      canvas.drawCircle(c, 8, PipPaints.hubStroke);
      final spoke = Offset(math.cos(phase), math.sin(phase)) * 6;
      canvas.drawLine(c - spoke, c + spoke, PipPaints.hubStroke);
    }
  }

  void _arm(Canvas canvas, double x, double angle, bool isLeft) {
    canvas.save();
    final pivot = Offset(isLeft ? x + 20 : x + 16, 138);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate((isLeft ? angle : -angle) * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    final shoulder = RRect.fromRectAndRadius(Rect.fromLTWH(x, 138, 38, 52), const Radius.circular(8));
    canvas.drawRRect(shoulder, PipPaints.armFill);
    canvas.drawRRect(shoulder, PipPaints.darkRustStroke);
    for (final fx in [x + 4, x + 22]) {
      final finger = RRect.fromRectAndRadius(Rect.fromLTWH(fx, 184, 12, 14), const Radius.circular(4));
      canvas.drawRRect(finger, PipPaints.rustFill);
      canvas.drawRRect(finger, PipPaints.darkRustStroke);
    }
    final wrist = RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, 176, 30, 12), const Radius.circular(5));
    canvas.drawRRect(wrist, PipPaints.rustFill);
    canvas.drawRRect(wrist, PipPaints.darkRustStroke);
    canvas.restore();
  }

  void _torso(Canvas canvas) {
    final torso = RRect.fromRectAndRadius(const Rect.fromLTWH(98, 154, 124, 82), const Radius.circular(10));
    canvas.drawRRect(torso, PipPaints.goldFill);
    canvas.drawRRect(torso, PipPaints.rustStroke);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(106, 160, 108, 4), const Radius.circular(2)), PipPaints.sheenFill);
    for (final vx in const [124.0, 155.0, 186.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(vx, 170, 9, 28), const Radius.circular(4.5)), PipPaints.rustFill);
    }
    final label = PipPaints.stampLabel;
    label.paint(canvas, Offset(160 - label.width / 2, 208));
  }

  void _chest(Canvas canvas, PipPose p) {
    final collar = RRect.fromRectAndRadius(const Rect.fromLTWH(92, 122, 136, 36), const Radius.circular(6));
    canvas.drawRRect(collar, PipPaints.rustFill);
    canvas.drawRRect(collar, PipPaints.darkRustStroke);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(104, 130, 30, 20), const Radius.circular(3)), PipPaints.badgeFill);
    canvas.drawLine(const Offset(109, 136), const Offset(123, 136), PipPaints.badgeLineStroke);
    canvas.drawLine(const Offset(109, 142), const Offset(129, 142), PipPaints.badgeLineStroke);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(168, 130, 34, 20), const Radius.circular(3)), PipPaints.consoleFill);
    canvas.drawCircle(const Offset(178, 140), 4, PipPaints.ledFill..color = p.led);
    // Voice waveform: dances while talking, rests as short bars otherwise.
    for (var i = 0; i < 4; i++) {
      final level = p.talking ? .35 + .65 * (.5 + .5 * math.sin(p.time * 14 + i * 1.7)) : .25;
      final h = 12 * level;
      final x = 186.0 + i * 3.6;
      canvas.drawLine(Offset(x, 140 - h / 2), Offset(x, 140 + h / 2), PipPaints.waveStroke);
    }
  }

  void _head(Canvas canvas, PipPose p) {
    canvas.save();
    const pivot = Offset(160, 128);
    canvas.translate(pivot.dx, pivot.dy + p.bob);
    canvas.rotate(p.head * math.pi / 180);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawRect(const Rect.fromLTWH(150, 96, 20, 32), PipPaints.rustFill);
    for (final y in const [108.0, 116.0, 124.0]) {
      canvas.drawLine(Offset(150, y), Offset(170, y), PipPaints.neckStroke);
    }
    paintPipEye(canvas, const Offset(108, 64), 1, p);
    paintPipEye(canvas, const Offset(212, 64), -1, p);
    canvas.restore();
  }

  /// Live painters repaint through [repaint]; fixed ones only when replaced.
  @override
  bool shouldRepaint(covariant PipVectorPainter old) => !identical(old.pose, pose);
}
