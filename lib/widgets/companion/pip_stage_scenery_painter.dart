import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Responsive full-screen painter for Pip's room, window, sky, and desk.
/// Seamlessly scales across any aspect ratio (tall mobile, tablet, or desktop Windows).
class PipStageSceneryPainter extends CustomPainter {
  final double hour; // 0.0 to 24.0

  const PipStageSceneryPainter({required this.hour});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    final H = size.height;

    final skyColors = _getSkyColors(hour);
    final e = math.sin(math.pi * (hour - 6) / 12);
    final l = ((e + 0.2) / 0.6).clamp(0.0, 1.0);
    final w = (math.exp(-math.pow(hour - 6.3, 2)) + math.exp(-math.pow(hour - 18.4, 2))).clamp(0.0, 1.0);

    // Dynamic Desk Height: desk rim aligns with the bottom of Pip's tracks (at ~46% of screen)
    final deskTop = H * 0.46;
    final deskHeight = H - deskTop;

    // 1. Back Wall (covers full screen behind window and desk)
    final wallColor = _mixColors(const Color(0xFF242A3D), const Color(0xFFEBE3D5), l);
    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = wallColor);

    // 2. Responsive Center Window (fits nicely between top safe area and desk)
    final winWidth = math.min(W * 0.88, 560.0);
    final winHeight = math.min(deskTop * 0.78, 300.0);
    final winLeft = (W - winWidth) / 2;
    final winTop = math.max(12.0, (deskTop - winHeight) * 0.35);
    final winRect = Rect.fromLTWH(winLeft, winTop, winWidth, winHeight);

    // Clip to window frame
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(winRect, const Radius.circular(8)));

    // Sky Gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [skyColors.$1, skyColors.$2],
      ).createShader(winRect);
    canvas.drawRect(winRect, skyPaint);

    // Night Stars
    if (l < 0.6) {
      final starOpacity = (1.0 - l * 1.6).clamp(0.0, 1.0);
      final starPaint = Paint()..color = Colors.white.withValues(alpha: starOpacity);
      _drawResponsiveStars(canvas, winRect, starPaint);
    }

    // Sun / Halo (Daytime)
    if (hour > 5.4 && hour < 18.6) {
      final a = math.pi * (hour - 6) / 12;
      final sunRadius = math.min(winWidth, winHeight) * 0.08;
      final sx = winRect.center.dx - math.cos(a) * (winWidth * 0.4);
      final sy = (winRect.bottom - 10) - math.sin(a) * (winHeight * 0.75);

      canvas.drawCircle(Offset(sx, sy), sunRadius * 2.0, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.25));
      final sunColor = _mixColors(const Color(0xFFFF9F45), const Color(0xFFFFE27A), (e * 2).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(sx, sy), sunRadius, Paint()..color = sunColor);
    }

    // Moon (Nighttime)
    final m = ((hour - 18) + 24) % 24;
    if (m <= 12) {
      final ma = math.pi * m / 12;
      final moonRadius = math.min(winWidth, winHeight) * 0.075;
      final mx = winRect.center.dx - math.cos(ma) * (winWidth * 0.4);
      final my = (winRect.bottom - 10) - math.sin(ma) * (winHeight * 0.75);
      canvas.drawCircle(Offset(mx, my), moonRadius, Paint()..color = const Color(0xFFF4F1E1));
      canvas.drawCircle(Offset(mx - 4, my - 3), moonRadius * 0.2, Paint()..color = const Color(0xFFDCD8C4));
      canvas.drawCircle(Offset(mx + 5, my + 4), moonRadius * 0.16, Paint()..color = const Color(0xFFDCD8C4));
    }

    // Rolling Hills (Adapted to window bounds)
    final hfColor = _mixColors(_mixColors(const Color(0xFF1B2750), const Color(0xFF7FAE85), l), const Color(0xFFA4627A), w * 0.25);
    final hfPath = Path()
      ..moveTo(winRect.left, winRect.bottom)
      ..lineTo(winRect.left, winRect.bottom - winHeight * 0.25)
      ..quadraticBezierTo(winRect.left + winWidth * 0.25, winRect.bottom - winHeight * 0.45, winRect.left + winWidth * 0.5, winRect.bottom - winHeight * 0.28)
      ..quadraticBezierTo(winRect.left + winWidth * 0.75, winRect.bottom - winHeight * 0.48, winRect.right, winRect.bottom - winHeight * 0.22)
      ..lineTo(winRect.right, winRect.bottom)
      ..close();
    canvas.drawPath(hfPath, Paint()..color = hfColor);

    final hnColor = _mixColors(_mixColors(const Color(0xFF121C38), const Color(0xFF5F9A6A), l), const Color(0xFF7A4A62), w * 0.25);
    final hnPath = Path()
      ..moveTo(winRect.left, winRect.bottom)
      ..lineTo(winRect.left, winRect.bottom - winHeight * 0.12)
      ..quadraticBezierTo(winRect.left + winWidth * 0.35, winRect.bottom - winHeight * 0.28, winRect.left + winWidth * 0.65, winRect.bottom - winHeight * 0.16)
      ..quadraticBezierTo(winRect.left + winWidth * 0.85, winRect.bottom - winHeight * 0.24, winRect.right, winRect.bottom - winHeight * 0.14)
      ..lineTo(winRect.right, winRect.bottom)
      ..close();
    canvas.drawPath(hnPath, Paint()..color = hnColor);

    canvas.restore(); // Restore Window Clip

    // 3. Wooden Window Frame & Mullions
    final framePaint = Paint()
      ..color = const Color(0xFF5B4A3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawRRect(RRect.fromRectAndRadius(winRect, const Radius.circular(8)), framePaint);

    final crossPaint = Paint()
      ..color = const Color(0xFF5B4A3A)
      ..strokeWidth = 5;
    canvas.drawLine(Offset(winRect.center.dx, winRect.top), Offset(winRect.center.dx, winRect.bottom), crossPaint);
    canvas.drawLine(Offset(winRect.left, winRect.center.dy), Offset(winRect.right, winRect.center.dy), crossPaint);

    // Window Sill
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(winRect.left - 12, winRect.bottom - 4, winWidth + 24, 14), const Radius.circular(4)),
      Paint()..color = const Color(0xFF6B5645),
    );

    // 4. Desk Surface (Spans all the way to screen bottom)
    canvas.drawRect(Rect.fromLTWH(0, deskTop, W, deskHeight), Paint()..color = const Color(0xFF8A6A4A));
    canvas.drawRect(Rect.fromLTWH(0, deskTop, W, 10), Paint()..color = const Color(0xFFA07C57));

    // 5. Desk Props: Plant (Left), Mug & Lamp (Right)
    _drawDeskProps(canvas, W, deskTop, l);
  }

  void _drawDeskProps(Canvas canvas, double W, double deskTop, double l) {
    // Potted plant on left
    final plantLeft = math.max(16.0, W * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(plantLeft, deskTop - 36, 42, 36), const Radius.circular(6)),
      Paint()..color = const Color(0xFFB5651D),
    );
    canvas.drawOval(Rect.fromLTWH(plantLeft + 12, deskTop - 64, 18, 48), Paint()..color = const Color(0xFF5FA35A));
    canvas.drawOval(Rect.fromLTWH(plantLeft + 3, deskTop - 56, 16, 40), Paint()..color = const Color(0xFF4F8F4A));
    canvas.drawOval(Rect.fromLTWH(plantLeft + 23, deskTop - 56, 16, 40), Paint()..color = const Color(0xFF4F8F4A));

    // Coffee mug on right
    final mugLeft = W - math.max(120.0, W * 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mugLeft, deskTop - 24, 30, 24), const Radius.circular(4)),
      Paint()..color = const Color(0xFFE8E4DC),
    );

    // Lamp on far right
    final lampRight = W - math.max(48.0, W * 0.1);
    canvas.drawOval(Rect.fromLTWH(lampRight - 22, deskTop - 8, 44, 10), Paint()..color = const Color(0xFF33383C));
    final lampPath = Path()
      ..moveTo(lampRight, deskTop - 4)
      ..lineTo(lampRight, deskTop - 30)
      ..lineTo(lampRight - 24, deskTop - 30)
      ..lineTo(lampRight - 24, deskTop - 48);
    canvas.drawPath(
      lampPath,
      Paint()
        ..color = const Color(0xFF3A3F45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );

    final lampIntensity = (1.2 - l * 1.6).clamp(0.0, 1.0);
    final shadeColor = _mixColors(const Color(0xFFC9A35A), const Color(0xFFFFD77A), lampIntensity);
    final shadePath = Path()
      ..moveTo(lampRight - 38, deskTop - 66)
      ..lineTo(lampRight - 6, deskTop - 66)
      ..lineTo(lampRight, deskTop - 46)
      ..lineTo(lampRight - 44, deskTop - 46)
      ..close();
    canvas.drawPath(shadePath, Paint()..color = shadeColor);

    // Cozy Lamp Glow
    if (lampIntensity > 0) {
      canvas.drawCircle(
        Offset(lampRight - 22, deskTop - 46),
        90,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFCF70).withValues(alpha: 0.45 * lampIntensity),
              const Color(0x00FFCF70),
            ],
          ).createShader(Rect.fromCircle(center: Offset(lampRight - 22, deskTop - 46), radius: 90)),
      );
    }
  }

  void _drawResponsiveStars(Canvas canvas, Rect winRect, Paint paint) {
    final offsets = [
      Offset(winRect.left + winRect.width * 0.12, winRect.top + winRect.height * 0.18),
      Offset(winRect.left + winRect.width * 0.28, winRect.top + winRect.height * 0.35),
      Offset(winRect.left + winRect.width * 0.42, winRect.top + winRect.height * 0.14),
      Offset(winRect.left + winRect.width * 0.62, winRect.top + winRect.height * 0.28),
      Offset(winRect.left + winRect.width * 0.78, winRect.top + winRect.height * 0.16),
      Offset(winRect.left + winRect.width * 0.88, winRect.top + winRect.height * 0.42),
      Offset(winRect.left + winRect.width * 0.22, winRect.top + winRect.height * 0.55),
      Offset(winRect.left + winRect.width * 0.52, winRect.top + winRect.height * 0.48),
      Offset(winRect.left + winRect.width * 0.72, winRect.top + winRect.height * 0.60),
    ];
    for (final pt in offsets) {
      canvas.drawCircle(pt, 1.2, paint);
    }
  }

  (Color, Color) _getSkyColors(double h) {
    final keyframes = [
      (0.0, const Color(0xFF0B1430), const Color(0xFF1B2A4E)),
      (5.0, const Color(0xFF1D2A55), const Color(0xFF4A4A7A)),
      (6.5, const Color(0xFF8A9BD0), const Color(0xFFF7B27A)),
      (9.0, const Color(0xFF6FB7E8), const Color(0xFFBFE3F5)),
      (12.0, const Color(0xFF4AA3DF), const Color(0xFFA9D8F2)),
      (16.0, const Color(0xFF5AAEE3), const Color(0xFFC8E6F4)),
      (18.5, const Color(0xFF6B6FB5), const Color(0xFFF4A35F)),
      (20.0, const Color(0xFF4A3A7A), const Color(0xFFC0607A)),
      (22.0, const Color(0xFF101A3C), const Color(0xFF24305A)),
      (24.0, const Color(0xFF0B1430), const Color(0xFF1B2A4E)),
    ];
    for (int i = 0; i < keyframes.length - 1; i++) {
      if (h >= keyframes[i].$1 && h <= keyframes[i + 1].$1) {
        final t = (h - keyframes[i].$1) / (keyframes[i + 1].$1 - keyframes[i].$1);
        return (_mixColors(keyframes[i].$2, keyframes[i + 1].$2, t), _mixColors(keyframes[i].$3, keyframes[i + 1].$3, t));
      }
    }
    return (const Color(0xFF0B1430), const Color(0xFF1B2A4E));
  }

  Color _mixColors(Color a, Color b, double t) {
    return Color.lerp(a, b, t) ?? a;
  }

  @override
  bool shouldRepaint(covariant PipStageSceneryPainter oldDelegate) => oldDelegate.hour != hour;
}
