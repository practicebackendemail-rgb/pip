import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'pip/pip_pose.dart';
import 'pip_params.dart';

enum PipEmote { none, question, sparkle, sweat, sleep, sound }

PipEmote emoteFor(PipMood mood) {
  switch (mood) {
    case PipMood.thinking:
      return PipEmote.question;
    case PipMood.happy:
    case PipMood.excited:
    case PipMood.laughing:
      return PipEmote.sparkle;
    case PipMood.unsure:
    case PipMood.sad:
      return PipEmote.sweat;
    case PipMood.sleepy:
    case PipMood.sleeping:
      return PipEmote.sleep;
    case PipMood.listening:
      return PipEmote.sound;
    default:
      return PipEmote.none;
  }
}

/// Small mood marks drawn above Pip's head, in the same 320-wide space as
/// [PipVectorPainter]. Each mark floats up and fades on a loop driven by [time].
class PipEmotePainter extends CustomPainter {
  final PipEmote emote;
  final PipPose pose;

  /// Repaints from the pose controller's clock instead of widget rebuilds.
  PipEmotePainter({required this.emote, required this.pose, super.repaint});

  double get time => pose.time;

  @override
  void paint(Canvas canvas, Size size) {
    if (emote == PipEmote.none) return;
    canvas.save();
    canvas.scale(size.width / 320.0);

    switch (emote) {
      case PipEmote.question:
        _float(canvas, 0, (p, o) => _text(canvas, '?', Offset(262, 30 - p * 14), 34, const Color(0xFFB4602A), o));
      case PipEmote.sparkle:
        _float(canvas, 0, (p, o) => _star(canvas, Offset(46, 36 - p * 14), 9, o));
        _float(canvas, .45, (p, o) => _star(canvas, Offset(276, 26 - p * 14), 7, o));
      case PipEmote.sweat:
        _float(canvas, 0, (p, o) => _drop(canvas, Offset(270, 18 + p * 10), o));
      case PipEmote.sleep:
        _float(canvas, 0, (p, o) => _text(canvas, 'z', Offset(258 + p * 6, 34 - p * 16), 24, const Color(0xFF9FB0B3), o));
        _float(canvas, .5, (p, o) => _text(canvas, 'z', Offset(276 + p * 6, 18 - p * 14), 17, const Color(0xFF9FB0B3), o));
      case PipEmote.sound:
        final o = 0.55 + 0.45 * math.sin(time * 6).abs();
        _arc(canvas, 14, o);
        _arc(canvas, 24, o * .7);
      case PipEmote.none:
        break;
    }
    canvas.restore();
  }

  /// Runs [draw] with progress 0..1 through a 2-second float cycle and the
  /// matching opacity (fade in, then out).
  void _float(Canvas canvas, double offset, void Function(double p, double opacity) draw) {
    final p = ((time / 2) + offset) % 1.0;
    final opacity = p < .3 ? p / .3 : 1 - (p - .3) / .7;
    draw(p, opacity.clamp(0.0, 1.0));
  }

  void _text(Canvas canvas, String s, Offset at, double size, Color color, double opacity) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color.withValues(alpha: opacity)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _star(Canvas canvas, Offset c, double r, double opacity) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
    canvas.drawPath(path, Paint()..color = const Color(0xFFF3C95A).withValues(alpha: opacity));
  }

  void _drop(Canvas canvas, Offset c, double opacity) {
    final path = Path()
      ..moveTo(c.dx, c.dy - 9)
      ..quadraticBezierTo(c.dx + 8, c.dy + 2, c.dx, c.dy + 6)
      ..quadraticBezierTo(c.dx - 8, c.dy + 2, c.dx, c.dy - 9);
    canvas.drawPath(path, Paint()..color = const Color(0xFF4AA3FF).withValues(alpha: opacity));
  }

  void _arc(Canvas canvas, double r, double opacity) {
    canvas.drawArc(
      Rect.fromCircle(center: const Offset(268, 60), radius: r),
      -math.pi / 3,
      2 * math.pi / 3,
      false,
      Paint()
        ..color = const Color(0xFF4AA3FF).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant PipEmotePainter old) => old.emote != emote || !identical(old.pose, pose);
}
