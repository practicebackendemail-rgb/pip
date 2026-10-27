import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Accurate vector representation of Pip 2.0 based on the official SVG blueprint.
class PipVectorPainter extends CustomPainter {
  final double lid;
  final double low;
  final double tilt;
  final double px;
  final double py;
  final double s;
  final double head;
  final double bob;
  final double armLeftAngle;
  final double armRightAngle;
  final Color ledColor;

  /// Seconds since the companion started; drives the chest waveform.
  final double time;

  /// When true the chest screen shows a moving voice waveform.
  final bool talking;

  const PipVectorPainter({
    this.time = 0,
    this.talking = false,
    this.lid = 0,
    this.low = 0,
    this.tilt = 14,
    this.px = 0,
    this.py = 0,
    this.s = 1.0,
    this.head = 0,
    this.bob = 0,
    this.armLeftAngle = 3,
    this.armRightAngle = 3,
    this.ledColor = const Color(0xFF6FBF73),
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Coordinate space normalized to 320x240 centered bounding box
    final scale = size.width / 320.0;
    canvas.save();
    canvas.scale(scale, scale);

    // Subtle contact shadow cast by Pip's tracks directly onto the wooden desk
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(const Rect.fromLTWH(28, 222, 68, 14), shadowPaint);
    canvas.drawOval(const Rect.fromLTWH(224, 222, 68, 14), shadowPaint);
    canvas.drawOval(const Rect.fromLTWH(85, 226, 150, 10), shadowPaint);

    const colorGold = Color(0xFFDCA21E);
    const colorRust = Color(0xFFA4551F);
    const colorDarkRust = Color(0xFF5A2D0F);
    const colorTrack = Color(0xFF2B2F31);
    const colorTrackRib = Color(0xFF4A5053);
    const colorChestBadge = Color(0xFFE4E8E6);
    const colorConsole = Color(0xFF1C2427);
    const colorAmberLed = Color(0xFFFFD77A);
    const colorLid = Color(0xFFC0821F);
    const colorEyeHousing = Color(0xFF1F2A2E);
    const colorPupil = Color(0xFF05080A);
    const colorSheen = Color(0xFFF3C95A);

    final rustStroke = Paint()
      ..color = colorRust
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final darkRustStroke = Paint()
      ..color = colorDarkRust
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // 1. Caterpillar Treads (Left & Right)
    void drawTrack(double x) {
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, 140, 52, 92), const Radius.circular(14));
      canvas.drawRRect(rect, Paint()..color = colorTrack);
      final ribPaint = Paint()
        ..color = colorTrackRib
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (double y = 150; y < 225; y += 10) {
        canvas.drawLine(Offset(x + 7, y), Offset(x + 45, y), ribPaint);
      }
      // Wheel hubs peeking through the tread
      for (final hy in [158.0, 214.0]) {
        canvas.drawCircle(Offset(x + 26, hy), 8, Paint()..color = const Color(0xFF3A3F43));
        canvas.drawCircle(
            Offset(x + 26, hy),
            8,
            Paint()
              ..color = colorTrackRib
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5);
        canvas.drawCircle(Offset(x + 26, hy), 2.5, Paint()..color = colorTrackRib);
      }
    }
    drawTrack(36);
    drawTrack(232);

    // 2. Arms (Left & Right with rotation)
    void drawArm(double x, double angle, bool isLeft) {
      canvas.save();
      final pivot = Offset(isLeft ? x + 20 : x + 16, 138);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate((isLeft ? angle : -angle) * math.pi / 180);
      canvas.translate(-pivot.dx, -pivot.dy);

      final shoulder = RRect.fromRectAndRadius(Rect.fromLTWH(x, 138, 38, 52), const Radius.circular(8));
      canvas.drawRRect(shoulder, Paint()..color = const Color(0xFF8A4A1C));
      canvas.drawRRect(shoulder, darkRustStroke);

      // Two-finger gripper
      for (final fx in [x + 4, x + 22]) {
        final finger = RRect.fromRectAndRadius(Rect.fromLTWH(fx, 184, 12, 14), const Radius.circular(4));
        canvas.drawRRect(finger, Paint()..color = colorRust);
        canvas.drawRRect(finger, darkRustStroke);
      }
      final wrist = RRect.fromRectAndRadius(Rect.fromLTWH(x + 4, 176, 30, 12), const Radius.circular(5));
      canvas.drawRRect(wrist, Paint()..color = colorRust);
      canvas.drawRRect(wrist, darkRustStroke);
      canvas.restore();
    }
    drawArm(56, armLeftAngle, true);
    drawArm(226, armRightAngle, false);

    // 3. Lower Torso & Grille
    final torsoRect = RRect.fromRectAndRadius(const Rect.fromLTWH(98, 154, 124, 82), const Radius.circular(10));
    canvas.drawRRect(torsoRect, Paint()..color = colorGold);
    canvas.drawRRect(torsoRect, rustStroke);
    // Top-edge sheen on the amber body
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(106, 160, 108, 4), const Radius.circular(2)),
      Paint()..color = colorSheen,
    );

    // Three vertical torso vent slats
    final slatPaint = Paint()..color = colorRust;
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(124, 170, 9, 28), const Radius.circular(4.5)), slatPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(155, 170, 9, 28), const Radius.circular(4.5)), slatPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(186, 170, 9, 28), const Radius.circular(4.5)), slatPaint);

    // PIP Nameplate Typography
    final tp = TextPainter(
      text: const TextSpan(
        text: 'PIP',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.2,
          color: Color(0xFF7A3D14),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(160 - (tp.width / 2), 208));

    // 4. Chest Collar & Controls
    final collar = RRect.fromRectAndRadius(const Rect.fromLTWH(92, 122, 136, 36), const Radius.circular(6));
    canvas.drawRRect(collar, Paint()..color = colorRust);
    canvas.drawRRect(collar, darkRustStroke);

    // White badge
    final badge = RRect.fromRectAndRadius(const Rect.fromLTWH(104, 130, 30, 20), const Radius.circular(3));
    canvas.drawRRect(badge, Paint()..color = colorChestBadge);
    final badgeLine = Paint()..color = const Color(0xFF4F5D61)..strokeWidth = 2;
    canvas.drawLine(const Offset(109, 136), const Offset(123, 136), badgeLine);
    canvas.drawLine(const Offset(109, 142), const Offset(129, 142), badgeLine);

    // Console Display + LED indicator
    final console = RRect.fromRectAndRadius(const Rect.fromLTWH(168, 130, 34, 20), const Radius.circular(3));
    canvas.drawRRect(console, Paint()..color = colorConsole);
    canvas.drawCircle(const Offset(178, 140), 4, Paint()..color = ledColor);
    // Voice waveform: dances while talking, rests as short bars otherwise
    final amberLed = Paint()
      ..color = colorAmberLed
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 4; i++) {
      final level = talking ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(time * 14 + i * 1.7)).abs() : 0.25;
      final h = 12 * level;
      final x = 186.0 + i * 3.6;
      canvas.drawLine(Offset(x, 140 - h / 2), Offset(x, 140 + h / 2), amberLed);
    }

    // 5. Neck & Rotating Head
    canvas.save();
    const headPivot = Offset(160, 128);
    canvas.translate(headPivot.dx, headPivot.dy + bob);
    canvas.rotate(head * math.pi / 180);
    canvas.translate(-headPivot.dx, -headPivot.dy);

    // Neck bellows
    canvas.drawRect(const Rect.fromLTWH(150, 96, 20, 32), Paint()..color = colorRust);
    final neckLine = Paint()..color = colorDarkRust..strokeWidth = 2;
    canvas.drawLine(const Offset(150, 108), const Offset(170, 108), neckLine);
    canvas.drawLine(const Offset(150, 116), const Offset(170, 116), neckLine);
    canvas.drawLine(const Offset(150, 124), const Offset(170, 124), neckLine);

    // 6. Binocular Eyes (Pip 2.0 Blueprint)
    _drawEye(canvas, const Offset(108, 64), 1.0, colorGold, colorRust, colorEyeHousing, colorPupil, colorLid);
    _drawEye(canvas, const Offset(212, 64), -1.0, colorGold, colorRust, colorEyeHousing, colorPupil, colorLid);

    canvas.restore(); // Head
    canvas.restore(); // Global
  }

  void _drawEye(
    Canvas canvas,
    Offset center,
    double sign,
    Color gold,
    Color rust,
    Color housing,
    Color pupil,
    Color lidColor,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt * sign * math.pi / 180);

    // Outer eye housing
    final eyeHousing = RRect.fromRectAndRadius(const Rect.fromLTWH(-52, -46, 104, 92), const Radius.circular(34));
    canvas.drawRRect(eyeHousing, Paint()..color = gold);
    canvas.drawRRect(
      eyeHousing,
      Paint()
        ..color = rust
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5,
    );
    // Light catching the top of the housing
    canvas.drawPath(
      Path()
        ..moveTo(-32, -38)
        ..quadraticBezierTo(0, -47, 32, -38),
      Paint()
        ..color = const Color(0xFFF3C95A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );

    // Small metallic screw accents
    final screwPaint = Paint()..color = rust;
    canvas.drawCircle(const Offset(-36, -30), 3.5, screwPaint);
    canvas.drawCircle(const Offset(36, 30), 3.5, screwPaint);

    // Dark outer lens frame
    canvas.drawCircle(Offset.zero, 42, Paint()..color = housing);

    // Inner eye with scale
    canvas.save();
    canvas.scale(s, s);

    // Circular clip path for eyelids and pupil
    final clipPath = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 38));
    canvas.clipPath(clipPath);

    canvas.drawCircle(Offset.zero, 38, Paint()..color = const Color(0xFF151A1C));
    // Lens ring
    canvas.drawCircle(
        Offset.zero,
        30,
        Paint()
          ..color = const Color(0xFF24363C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);

    // Pupil with eye gaze tracking
    canvas.save();
    canvas.translate(px * 11, py * 8);
    canvas.drawCircle(Offset.zero, 19, Paint()..color = pupil);
    canvas.drawCircle(const Offset(-7, -8), 6, Paint()..color = Colors.white.withValues(alpha: 0.92));
    canvas.drawCircle(const Offset(6, 7), 2.5, Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.restore();

    // Top eyelid (descends downward)
    final topLidY = -110.0 + (lid * 76.0);
    canvas.drawRect(Rect.fromLTWH(-42, topLidY, 84, 72), Paint()..color = lidColor);

    // Lower eyelid (ascends upward)
    final lowLidY = 38.0 - (low * 76.0);
    canvas.drawRect(Rect.fromLTWH(-42, lowLidY, 84, 72), Paint()..color = lidColor);

    canvas.restore(); // Scale & Clip
    canvas.restore(); // Eye
  }

  @override
  bool shouldRepaint(covariant PipVectorPainter old) =>
      old.lid != lid ||
      old.low != low ||
      old.tilt != tilt ||
      old.px != px ||
      old.py != py ||
      old.s != s ||
      old.head != head ||
      old.bob != bob ||
      old.armLeftAngle != armLeftAngle ||
      old.armRightAngle != armRightAngle ||
      old.ledColor != ledColor ||
      (talking && old.time != time) ||
      old.talking != talking;
}
