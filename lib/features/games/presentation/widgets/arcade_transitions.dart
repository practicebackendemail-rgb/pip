import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/pip_sfx_service.dart';
import 'arcade.dart';

/// How a game-mode screen arrives.
enum ArcadeEntrance {
  /// The arcade itself: a coin drops into a slot and a ring of light opens
  /// onto the arcade.
  coin,

  /// A game: "PLAYER 1 / READY" slides in, then the table rises.
  ready,
}

/// A page that plays an arcade entrance (and the same motion backwards when
/// leaving). With reduced motion it just fades.
CustomTransitionPage<void> arcadePage({required LocalKey key, required Widget child, required ArcadeEntrance entrance}) {
  final coin = entrance == ArcadeEntrance.coin;
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Duration(milliseconds: coin ? 1600 : 1400),
    reverseTransitionDuration: Duration(milliseconds: coin ? 700 : 450),
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return FadeTransition(opacity: animation, child: child);
      return coin ? _CoinEntrance(animation: animation, child: child) : _ReadySplash(animation: animation, child: child);
    },
  );
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Insert coin: night falls, a gold coin flips up and drops into a neon
/// slot, then a ring of light opens from the slot onto the arcade. Only the
/// coin, the slot and one circular clip move, so it stays smooth on phones.
class _CoinEntrance extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  const _CoinEntrance({required this.animation, required this.child});

  @override
  State<_CoinEntrance> createState() => _CoinEntranceState();
}

class _CoinEntranceState extends State<_CoinEntrance> {
  final Set<int> _played = {};

  void _cue(int id, double t, double at, VoidCallback sound) {
    if (widget.animation.status != AnimationStatus.forward || t < at || !_played.add(id)) return;
    sound();
  }

  @override
  Widget build(BuildContext context) {
    final page = RepaintBoundary(child: widget.child);
    return LayoutBuilder(builder: (context, box) {
      final size = box.biggest;
      final slot = Offset(size.width / 2, size.height * .46);
      final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
      final start = Offset(size.width * .5, size.height * 1.05);
      final peakY = size.height * .14;
      return AnimatedBuilder(
        animation: widget.animation,
        builder: (context, page) {
          final t = widget.animation.value;
          if (t >= 1) return page!;
          _cue(0, t, .06, PipSfxService.chirp);
          _cue(1, t, .5, PipSfxService.blip);
          _cue(2, t, .56, PipSfxService.excited);

          final night = Curves.easeOut.transform(_span(t, 0, .2));
          final slotIn = Curves.easeOutBack.transform(_span(t, .12, .34));
          final flight = _span(t, .1, .5);
          final clink = _span(t, .5, .62);
          final open = Curves.easeInOutCubic.transform(_span(t, .56, 1));
          final radius = maxRadius * open;

          // Up from the bottom to the peak (decelerating), then down into the slot (accelerating).
          final rise = Curves.easeOutCubic.transform(_span(flight, 0, .6));
          final fall = Curves.easeInCubic.transform(_span(flight, .6, 1));
          final coinY = flight < .6 ? start.dy + (peakY - start.dy) * rise : peakY + (slot.dy - peakY) * fall;
          final coinX = start.dx + math.sin(flight * math.pi) * size.width * .1;
          final sink = flight > .9 ? 1 - (flight - .9) * 8 : 1.0;
          final turn = math.cos(flight * math.pi * 7).abs().clamp(.08, 1.0);

          return Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Arcade.night.withValues(alpha: .94 * night)),
                if (open > 0) ClipPath(clipper: _CircleClip(slot, radius), child: page),
                if (open > 0 && open < 1) IgnorePointer(child: CustomPaint(painter: _RingPainter(slot, radius, 1 - open))),
                if (open < .6)
                  Positioned(
                    left: slot.dx - 70,
                    top: slot.dy - 23,
                    width: 140,
                    height: 100,
                    child: Opacity(
                      opacity: (1 - open / .6).clamp(0.0, 1.0),
                      child: Transform.scale(scale: slotIn, child: _Slot(flash: clink > 0 && clink < 1 ? 1 - clink : 0)),
                    ),
                  ),
                if (flight > 0 && flight < 1)
                  Positioned(
                    left: coinX - 26,
                    top: coinY - 26,
                    width: 52,
                    height: 52,
                    child: Transform(
                      alignment: Alignment.center,
                      // Spinning: squash with the coin's turn; shrink as it enters the slot.
                      transform: Matrix4.diagonal3Values(turn * sink.clamp(0.0, 1.0), sink.clamp(0.0, 1.0), 1),
                      child: const _Coin(),
                    ),
                  ),
              ],
            ),
          );
        },
        child: page,
      );
    });
  }
}

class _CircleClip extends CustomClipper<Path> {
  final Offset centre;
  final double radius;
  _CircleClip(this.centre, this.radius);

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: centre, radius: radius));

  @override
  bool shouldReclip(_CircleClip o) => o.radius != radius || o.centre != centre;
}

/// The neon ring at the edge of the opening circle.
class _RingPainter extends CustomPainter {
  final Offset centre;
  final double radius;
  final double strength;
  _RingPainter(this.centre, this.radius, this.strength);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(centre, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = Arcade.amber.withValues(alpha: .25 * strength));
    canvas.drawCircle(centre, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Arcade.amber.withValues(alpha: strength));
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.radius != radius || o.strength != strength;
}

class _Coin extends StatelessWidget {
  const _Coin();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFFFF1B0), Arcade.amber, Color(0xFFB07A10)],
            stops: [0, .55, 1],
            center: Alignment(-.3, -.3),
          ),
          border: Border.all(color: const Color(0xFF8A5A00), width: 2),
          boxShadow: const [BoxShadow(color: Color(0x88FFC23A), blurRadius: 12)],
        ),
        alignment: Alignment.center,
        child: const Text('P', style: TextStyle(color: Color(0xFF8A5A00), fontWeight: FontWeight.w900, fontSize: 24)),
      );
}

/// A neon coin slot with INSERT COIN under it; [flash] lights it up.
class _Slot extends StatelessWidget {
  final double flash;
  const _Slot({required this.flash});

  @override
  Widget build(BuildContext context) {
    final edge = Color.lerp(Arcade.pink, Colors.white, flash)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120,
          height: 46,
          decoration: BoxDecoration(
            color: Arcade.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: edge, width: 2),
            boxShadow: [BoxShadow(color: edge.withValues(alpha: .4 + .4 * flash), blurRadius: 14 + 20 * flash)],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 70,
            height: 8,
            decoration: BoxDecoration(color: Color.lerp(Colors.black, Arcade.amber, flash), borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 10),
        const Text('INSERT COIN', style: TextStyle(color: Arcade.teal, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
      ],
    );
  }
}

/// "PLAYER 1 / READY" slides in letter by letter and holds, then the game
/// rises in underneath while the words drift up and fade.
class _ReadySplash extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _ReadySplash({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final t = animation.value;
        if (t >= 1) return child!;
        final words = Curves.easeOutCubic.transform(_span(t, 0, .4));
        final leave = Curves.easeInOutCubic.transform(_span(t, .55, 1));
        return Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const _NightSky(),
              if (leave > 0)
                Transform.translate(
                  offset: Offset(0, 60 * (1 - leave)),
                  child: Stack(fit: StackFit.expand, children: [
                    RepaintBoundary(child: child),
                    if (leave < 1) IgnorePointer(child: ColoredBox(color: Arcade.night.withValues(alpha: 1 - leave))),
                  ]),
                ),
              IgnorePointer(
                child: Opacity(
                  opacity: 1 - leave,
                  child: Transform.translate(
                    offset: Offset(0, -40 * leave),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Opacity(opacity: words, child: Text('PLAYER 1', style: Arcade.title(Arcade.teal, size: 24))),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final (i, ch) in 'READY'.split('').indexed)
                                Builder(builder: (context) {
                                  final p = Curves.easeOutBack.transform(_span(t, .05 + i * .05, .3 + i * .05));
                                  return Opacity(
                                    opacity: p.clamp(0.0, 1.0),
                                    child: Transform.translate(
                                      offset: Offset(0, 30 * (1 - p)),
                                      child: Text(ch, style: Arcade.title(Arcade.amber, size: 56)),
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

class _NightSky extends StatelessWidget {
  const _NightSky();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Arcade.night, Arcade.deep, Color(0xFF1B1036)],
          ),
        ),
      );
}
