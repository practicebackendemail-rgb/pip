import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Open sky behind Pip's island: hour-driven gradient, sun and moon on an
/// arc, twinkling stars at night, drifting clouds, and an occasional bird.
/// [time] is seconds of animation; [hour] is local time as 0..24.
class PocketSkyPainter extends CustomPainter {
  final double hour;
  final double time;
  final bool overcast;

  const PocketSkyPainter({required this.hour, required this.time, this.overcast = false});

  // (hour, top, bottom) keyframes from the Pip design notes.
  static const _keys = <(double, Color, Color)>[
    (0, Color(0xFF0B1330), Color(0xFF1C2550)),
    (5, Color(0xFF1A2147), Color(0xFF3A3F7A)),
    (6.5, Color(0xFF6E6FB0), Color(0xFFF6B48A)),
    (9, Color(0xFF4AA3DF), Color(0xFFBFE3F5)),
    (12, Color(0xFF3D98DA), Color(0xFFA9D8F2)),
    (16, Color(0xFF4F9FD8), Color(0xFFCFE6F2)),
    (18.5, Color(0xFFE48B5A), Color(0xFFFCD39B)),
    (20, Color(0xFF3B3A72), Color(0xFF8A5F8C)),
    (22, Color(0xFF141B3D), Color(0xFF2A3166)),
    (24, Color(0xFF0B1330), Color(0xFF1C2550)),
  ];

  static (Color, Color) skyAt(double hour) {
    for (var i = 0; i < _keys.length - 1; i++) {
      final a = _keys[i], b = _keys[i + 1];
      if (hour >= a.$1 && hour <= b.$1) {
        final t = (hour - a.$1) / (b.$1 - a.$1);
        return (Color.lerp(a.$2, b.$2, t)!, Color.lerp(a.$3, b.$3, t)!);
      }
    }
    return (_keys.first.$2, _keys.first.$3);
  }

  /// 0 in full day, 1 in deep night.
  static double nightness(double hour) {
    final day = math.sin(math.pi * (hour - 6) / 12);
    return (1 - (day + .25).clamp(0.0, 1.0)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final (top, bottom) = skyAt(hour);
    final grey = overcast ? .45 : 0.0;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(top, const Color(0xFF7D8A92), grey)!, Color.lerp(bottom, const Color(0xFFB8C1C6), grey)!],
        ).createShader(Offset.zero & size),
    );

    final night = nightness(hour);
    _stars(canvas, size, night * (overcast ? .2 : 1));
    _sunAndMoon(canvas, size, overcast);
    _clouds(canvas, size, night, overcast);
    _bird(canvas, size, night);
  }

  void _stars(Canvas canvas, Size size, double night) {
    if (night <= 0.05) return;
    final rng = math.Random(7); // fixed layout, only brightness animates
    for (var i = 0; i < 46; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * .6);
      final twinkle = .35 + .65 * (0.5 + 0.5 * math.sin(time * (1 + rng.nextDouble() * 2) + i));
      canvas.drawCircle(p, .6 + rng.nextDouble() * 1.2, Paint()..color = Colors.white.withValues(alpha: night * twinkle));
    }
  }

  void _sunAndMoon(Canvas canvas, Size size, bool overcast) {
    Offset arc(double h) {
      final a = math.pi * (h - 6) / 12;
      return Offset(size.width * (.5 - .42 * math.cos(a)), size.height * (.62 - .48 * math.sin(a)));
    }

    if (hour > 5.5 && hour < 18.8) {
      final c = arc(hour);
      final alpha = overcast ? .35 : 1.0;
      canvas.drawCircle(c, 46, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: .25 * alpha));
      canvas.drawCircle(c, 24, Paint()..color = const Color(0xFFFFE27A).withValues(alpha: alpha));
    } else {
      final c = arc(((hour + 12) % 24));
      canvas.drawCircle(c, 30, Paint()..color = const Color(0xFFF4F1E1).withValues(alpha: .12));
      canvas.drawCircle(c, 18, Paint()..color = const Color(0xFFF4F1E1));
      canvas.drawCircle(c + const Offset(-5, -4), 3.5, Paint()..color = const Color(0xFFDCD8C4));
      canvas.drawCircle(c + const Offset(6, 5), 2.5, Paint()..color = const Color(0xFFDCD8C4));
    }
  }

  void _clouds(Canvas canvas, Size size, double night, bool overcast) {
    final count = overcast ? 7 : 4;
    final base = Color.lerp(Colors.white, const Color(0xFF4A5378), night)!;
    final color = Color.lerp(base, const Color(0xFF9AA3A8), overcast ? .5 : 0)!;
    for (var i = 0; i < count; i++) {
      final speed = 6.0 + i * 2.3;
      final span = size.width + 200;
      final x = ((time * speed + i * 173) % span) - 100;
      final y = size.height * (.08 + (i * .11) % .42);
      final s = .7 + (i % 3) * .25;
      final paint = Paint()..color = color.withValues(alpha: .85);
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 74 * s, height: 24 * s), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x + 16 * s, y - 9 * s), width: 40 * s, height: 22 * s), paint);
      canvas.drawOval(Rect.fromCenter(center: Offset(x - 18 * s, y - 4 * s), width: 34 * s, height: 18 * s), paint);
    }
  }

  /// A bird crosses every 26 s during the day.
  static Offset? birdAt(double time, Size size, double hour) {
    if (nightness(hour) > .6) return null;
    const period = 26.0, flight = 9.0;
    final t = time % period;
    if (t > flight) return null;
    final p = t / flight;
    return Offset(-30 + p * (size.width + 60), size.height * (.22 - .08 * math.sin(p * math.pi)));
  }

  void _bird(Canvas canvas, Size size, double night) {
    final at = birdAt(time, size, hour);
    if (at == null) return;
    final flap = math.sin(time * 18) * 5;
    final path = Path()
      ..moveTo(at.dx - 9, at.dy)
      ..quadraticBezierTo(at.dx - 4.5, at.dy - 5 - flap, at.dx, at.dy)
      ..quadraticBezierTo(at.dx + 4.5, at.dy - 5 - flap, at.dx + 9, at.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF2B2F31)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant PocketSkyPainter old) =>
      old.time != time || old.hour != hour || old.overcast != overcast;
}
