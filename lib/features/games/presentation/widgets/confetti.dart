import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arcade.dart';

/// A one-shot confetti burst. Change [burst] to fire again.
class ConfettiBurst extends StatefulWidget {
  final int burst;
  final List<Color> colors;
  const ConfettiBurst({super.key, required this.burst, this.colors = const [Arcade.amber, Arcade.teal, Arcade.pink, Arcade.violet]});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Bit {
  final double angle, speed, spin, size;
  final Color color;
  _Bit(math.Random r, List<Color> colors)
      : angle = -math.pi / 2 + (r.nextDouble() - .5) * math.pi * 1.1,
        speed = 380 + r.nextDouble() * 520,
        spin = (r.nextDouble() - .5) * 14,
        size = 5 + r.nextDouble() * 6,
        color = colors[r.nextInt(colors.length)];
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  List<_Bit> _bits = const [];

  @override
  void didUpdateWidget(ConfettiBurst old) {
    super.didUpdateWidget(old);
    if (widget.burst != old.burst && widget.burst > 0) _fire();
  }

  void _fire() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final r = math.Random();
    setState(() => _bits = List.generate(90, (_) => _Bit(r, widget.colors)));
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: CustomPaint(painter: _ConfettiPainter(_c, _bits), size: Size.infinite),
      );
}

class _ConfettiPainter extends CustomPainter {
  final Animation<double> t;
  final List<_Bit> bits;
  _ConfettiPainter(this.t, this.bits) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t.value == 0 || t.value == 1) return;
    final secs = t.value * 2.2;
    final origin = Offset(size.width / 2, size.height * .55);
    final p = Paint();
    for (final b in bits) {
      final x = origin.dx + math.cos(b.angle) * b.speed * secs;
      final y = origin.dy + math.sin(b.angle) * b.speed * secs + 520 * secs * secs;
      p.color = b.color.withValues(alpha: (1 - t.value).clamp(0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(b.spin * secs);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: b.size, height: b.size * .55), const Radius.circular(1.5)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.bits != bits;
}
