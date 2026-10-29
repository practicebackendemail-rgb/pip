import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../domain/pip_banter.dart';

/// Arcade look for game mode: deep night background, neon accents, glow.
abstract final class Arcade {
  static const night = Color(0xFF0B0F1A);
  static const deep = Color(0xFF121A2E);
  static const panel = Color(0xFF17213A);
  static const amber = Color(0xFFFFC23A);
  static const teal = Color(0xFF2EF2C8);
  static const pink = Color(0xFFFF4FD8);
  static const violet = Color(0xFF8B7CFF);
  static const text = Color(0xFFEFF3FF);
  static const muted = Color(0xFF8C97B8);

  static List<Shadow> glow(Color c, {double strength = 1}) => [
        Shadow(color: c.withValues(alpha: .9), blurRadius: 6 * strength),
        Shadow(color: c.withValues(alpha: .6), blurRadius: 18 * strength),
      ];

  static List<BoxShadow> boxGlow(Color c, {double strength = 1}) => [
        BoxShadow(color: c.withValues(alpha: .45), blurRadius: 18 * strength, spreadRadius: 1),
        BoxShadow(color: c.withValues(alpha: .25), blurRadius: 40 * strength, spreadRadius: 2),
      ];

  static TextStyle title(Color c, {double size = 28}) => TextStyle(
        color: c,
        fontSize: size,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
        shadows: glow(c),
      );

  /// Plays the sound for a banter reaction.
  static void sound(PipSoundCue cue) => switch (cue) {
        PipSoundCue.none => null,
        PipSoundCue.chirp => PipSfxService.chirp(),
        PipSoundCue.blip => PipSfxService.blip(),
        PipSoundCue.thinking => PipSfxService.thinking(),
        PipSoundCue.happy => PipSfxService.happy(),
        PipSoundCue.excited => PipSfxService.excited(),
        PipSoundCue.laugh => PipSfxService.laugh(),
        PipSoundCue.sad => PipSfxService.sad(),
        PipSoundCue.unsure => PipSfxService.unsure(),
      };
}

/// Night sky with a neon grid rolling towards you. Still when the system
/// asks for reduced motion.
class ArcadeBackground extends StatefulWidget {
  final Widget child;
  final Color tint;
  const ArcadeBackground({super.key, required this.child, this.tint = Arcade.violet});

  @override
  State<ArcadeBackground> createState() => _ArcadeBackgroundState();
}

class _ArcadeBackgroundState extends State<ArcadeBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MediaQuery.disableAnimationsOf(context) ? _c.stop() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GridPainter(_c, widget.tint),
        child: widget.child,
      );
}

class _GridPainter extends CustomPainter {
  final Animation<double> t;
  final Color tint;
  _GridPainter(this.t, this.tint) : super(repaint: t);

  static final _stars = List.generate(60, (i) {
    final r = math.Random(i * 7919);
    return Offset(r.nextDouble(), r.nextDouble() * .55);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Arcade.night, Arcade.deep, Color(0xFF1B1036)],
        ).createShader(rect),
    );
    final star = Paint()..color = Colors.white;
    for (final (i, s) in _stars.indexed) {
      final twinkle = .35 + .65 * (0.5 + 0.5 * math.sin(t.value * 2 * math.pi + i));
      canvas.drawCircle(Offset(s.dx * size.width, s.dy * size.height), i % 5 == 0 ? 1.4 : .8,
          star..color = Colors.white.withValues(alpha: twinkle * .8));
    }
    // Perspective grid on the bottom 40%.
    final horizon = size.height * .62;
    final line = Paint()
      ..color = tint.withValues(alpha: .35)
      ..strokeWidth = 1;
    for (var i = 0; i < 12; i++) {
      final p = ((i + t.value) / 12);
      final y = horizon + (size.height - horizon) * p * p;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line..color = tint.withValues(alpha: .1 + .35 * p));
    }
    final cx = size.width / 2;
    for (var i = -10; i <= 10; i++) {
      canvas.drawLine(Offset(cx + i * 24, horizon), Offset(cx + i * size.width * .22, size.height), line..color = tint.withValues(alpha: .22));
    }
    canvas.drawLine(Offset(0, horizon), Offset(size.width, horizon),
        Paint()
          ..color = Arcade.pink.withValues(alpha: .7)
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.tint != tint;
}

/// A rounded panel with a neon edge.
class NeonPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double glow;
  const NeonPanel({super.key, required this.child, this.color = Arcade.violet, this.padding = const EdgeInsets.all(14), this.glow = 1});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Arcade.panel.withValues(alpha: .85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 2),
          boxShadow: Arcade.boxGlow(color, strength: glow),
        ),
        child: child,
      );
}

/// Chunky arcade button that sinks when pressed.
class ArcadeButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final double fontSize;
  const ArcadeButton({super.key, required this.label, this.icon, this.color = Arcade.amber, this.onPressed, this.fontSize = 15});

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final c = enabled ? widget.color : Arcade.muted;
    final depth = _down ? 1.0 : 5.0;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                PipSfxService.blip();
                widget.onPressed!();
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          margin: EdgeInsets.only(top: 5 - depth),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: Color.lerp(c, Colors.black, .45)!, offset: Offset(0, depth)),
              if (enabled) ...Arcade.boxGlow(c, strength: .5),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, color: Arcade.night, size: widget.fontSize + 3), const SizedBox(width: 8)],
              Text(widget.label.toUpperCase(),
                  style: TextStyle(color: Arcade.night, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: widget.fontSize)),
            ],
          ),
        ),
      ),
    );
  }
}
