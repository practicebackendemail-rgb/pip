import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Pip's floating island, drawn in a 300 x 170 box: grass top, layered earth
/// underneath with hanging roots, a swaying tree, a tiny house for Pip's
/// things, flowers, and a lantern that glows at night.
class PocketIslandPainter extends CustomPainter {
  final double time;
  final double night; // 0 day … 1 night

  const PocketIslandPainter({required this.time, required this.night});

  static const double width = 300, height = 180;

  /// Walkable grass: x from [minX] to [maxX], depth from [backY] (far) to
  /// [frontY] (near). Pip's feet land anywhere in that oval band.
  static const double minX = 48, maxX = 252, backY = 50, frontY = 84;

  /// Kept for callers that only need one ground line (the middle of the grass).
  static const double surfaceY = (backY + frontY) / 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / width, size.height / height);

    // Underside: three earth bands narrowing to a point, with roots.
    final under = Path()
      ..moveTo(6, 66)
      ..quadraticBezierTo(56, 146, 150, 170)
      ..quadraticBezierTo(244, 146, 294, 66)
      ..close();
    canvas.drawPath(under, Paint()..color = const Color(0xFF8A6A4A));
    final band = Path()
      ..moveTo(30, 100)
      ..quadraticBezierTo(150, 130, 270, 100);
    canvas.drawPath(band, _stroke(const Color(0xFF6B5040), 4));
    final band2 = Path()
      ..moveTo(74, 132)
      ..quadraticBezierTo(150, 152, 226, 132);
    canvas.drawPath(band2, _stroke(const Color(0xFF6B5040), 3));
    for (final (x, start, len) in [(96.0, 140.0, 20.0), (150.0, 168.0, 10.0), (204.0, 140.0, 16.0)]) {
      final sway = math.sin(time * 1.4 + x) * 3;
      final root = Path()
        ..moveTo(x, start)
        ..quadraticBezierTo(x + sway, start + len / 2, x - sway, start + len);
      canvas.drawPath(root, _stroke(const Color(0xFF5A4334), 2.5));
    }

    // Grass cap with a darker rim: deep enough for Pip to roam front to back.
    final top = Rect.fromCenter(center: const Offset(150, 66), width: 290, height: 72);
    canvas.drawOval(top, Paint()..color = Color.lerp(const Color(0xFF7DBA68), const Color(0xFF3F5E48), night)!);
    canvas.drawOval(top.deflate(10), Paint()..color = Color.lerp(const Color(0xFF8CC874), const Color(0xFF486B50), night)!);
    canvas.drawOval(top, _stroke(Color.lerp(const Color(0xFF5F9150), const Color(0xFF2F4A38), night)!, 3));

    _house(canvas);
    _tree(canvas);
    _flowers(canvas);
    _lantern(canvas);
    canvas.restore();
  }

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _house(Canvas canvas) {
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(30, 30, 30, 24), const Radius.circular(3));
    canvas.drawRRect(body, Paint()..color = const Color(0xFFC79A6B));
    final roof = Path()
      ..moveTo(26, 32)
      ..lineTo(45, 16)
      ..lineTo(64, 32)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFFA4551F));
    final window = Paint()..color = Color.lerp(const Color(0xFF5B4A3A), const Color(0xFFFFD77A), night)!;
    canvas.drawRect(const Rect.fromLTWH(48, 38, 7, 7), window);
    canvas.drawRect(const Rect.fromLTWH(35, 40, 8, 14), Paint()..color = const Color(0xFF7A5A43));
  }

  void _tree(Canvas canvas) {
    canvas.drawRect(const Rect.fromLTWH(243, 22, 7, 34), Paint()..color = const Color(0xFF7A5A43));
    canvas.save();
    canvas.translate(246, 22);
    canvas.rotate(math.sin(time * 1.1) * .05);
    final leaf = Paint()..color = Color.lerp(const Color(0xFF4F8F4A), const Color(0xFF2E5236), night)!;
    canvas.drawCircle(const Offset(0, -10), 20, leaf);
    canvas.drawCircle(const Offset(-14, 0), 14, leaf);
    canvas.drawCircle(const Offset(14, -2), 15, leaf);
    canvas.restore();
  }

  void _flowers(Canvas canvas) {
    for (final (x, color) in [(92.0, const Color(0xFFF5B8A6)), (104.0, const Color(0xFFFFE27A)), (212.0, const Color(0xFFC9B6F2))]) {
      final bend = math.sin(time * 2 + x) * 1.5;
      canvas.drawLine(Offset(x, 60), Offset(x + bend, 52), _stroke(const Color(0xFF4F8F4A), 1.5));
      canvas.drawCircle(Offset(x + bend, 51), 2.6, Paint()..color = color);
    }
  }

  void _lantern(Canvas canvas) {
    canvas.drawLine(const Offset(270, 60), const Offset(270, 38), _stroke(const Color(0xFF3A3F45), 2.5));
    canvas.drawRect(const Rect.fromLTWH(265, 30, 10, 10), Paint()..color = const Color(0xFF3A3F45));
    if (night > .2) {
      final flicker = .85 + .15 * math.sin(time * 7);
      canvas.drawCircle(const Offset(270, 35), 26,
          Paint()..color = const Color(0xFFFFCF70).withValues(alpha: .28 * night * flicker));
      canvas.drawCircle(const Offset(270, 35), 3.5, Paint()..color = const Color(0xFFFFE27A).withValues(alpha: night));
    }
  }

  @override
  bool shouldRepaint(covariant PocketIslandPainter old) => old.time != time || old.night != night;
}
