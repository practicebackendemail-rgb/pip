import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/pip_sfx_service.dart';
import '../../../../widgets/pip_companion.dart';
import 'arcade.dart';

/// How a game-mode screen arrives.
enum ArcadeEntrance {
  /// The arcade itself: night falls, Pip rides in on an arcade machine,
  /// its marquee lights up, and the view glides into the machine's screen.
  cabinet,

  /// A game: "PLAYER 1 / READY" slides in, then the table rises.
  ready,
}

/// A page that plays an arcade entrance (and the same motion backwards when
/// leaving). With reduced motion it just fades.
CustomTransitionPage<void> arcadePage({required LocalKey key, required Widget child, required ArcadeEntrance entrance}) {
  final cabinet = entrance == ArcadeEntrance.cabinet;
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: Duration(milliseconds: cabinet ? 2600 : 1400),
    reverseTransitionDuration: Duration(milliseconds: cabinet ? 1100 : 450),
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return FadeTransition(opacity: animation, child: child);
      return cabinet ? _CabinetEntrance(animation: animation, child: child) : _ReadySplash(animation: animation, child: child);
    },
  );
}

double _span(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

/// Geometry of the arcade machine for a viewport. The screen keeps the
/// viewport's aspect ratio, so zooming into it lands exactly on the page.
class _Cabinet {
  final Size view;
  late final double width = view.width * .66;
  late final double screenW = width * .78;
  late final double screenH = screenW * view.height / view.width;
  late final double marqueeH = width * .26;
  late final double panelH = width * .3;
  late final double height = marqueeH + screenH + panelH + width * .14;
  late final Rect body = Rect.fromLTWH((view.width - width) / 2, view.height - height - view.height * .04, width, height);
  late final Rect marquee = Rect.fromLTWH(body.left + width * .06, body.top + width * .05, width * .88, marqueeH);
  late final Rect screen = Rect.fromLTWH(body.left + (width - screenW) / 2, marquee.bottom + width * .05, screenW, screenH);
  late final Rect panel = Rect.fromLTWH(body.left, screen.bottom + width * .04, width, panelH);
  _Cabinet(this.view);
}

class _CabinetEntrance extends StatefulWidget {
  final Animation<double> animation;
  final Widget child;
  const _CabinetEntrance({required this.animation, required this.child});

  @override
  State<_CabinetEntrance> createState() => _CabinetEntranceState();
}

class _CabinetEntranceState extends State<_CabinetEntrance> {
  final Set<int> _played = {};

  void _cue(int id, double t, double at, VoidCallback sound) {
    if (widget.animation.status != AnimationStatus.forward || t < at || !_played.add(id)) return;
    sound();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final c = _Cabinet(box.biggest);
      return AnimatedBuilder(
        animation: widget.animation,
        builder: (context, child) {
          final t = widget.animation.value;
          if (t >= 1) return child!;
          _cue(0, t, .12, PipSfxService.chirp);
          _cue(1, t, .36, PipSfxService.blip);
          _cue(2, t, .6, PipSfxService.excited);

          final night = Curves.easeOut.transform(_span(t, 0, .22));
          final rise = Curves.easeOutCubic.transform(_span(t, .08, .4));
          final lights = _span(t, .3, .6);
          final screenOn = Curves.easeInOut.transform(_span(t, .5, .66));
          final zoom = Curves.easeInOutCubic.transform(_span(t, .62, 1));

          // Glide into the machine's screen: scale about its centre while
          // moving that centre to the middle of the view.
          final k = math.exp(math.log(c.view.width / c.screenW) * zoom);
          final from = c.screen.center, to = c.view.center(Offset.zero);
          final centre = Offset.lerp(from, to, zoom)!;
          final camera = Matrix4.identity()
            ..translateByDouble(centre.dx, centre.dy, 0, 1)
            ..scaleByDouble(k, k, 1, 1)
            ..translateByDouble(-from.dx, -from.dy, 0, 1);

          return Material(
            type: MaterialType.transparency,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Night falls over whatever was behind.
                Opacity(opacity: night, child: const _NightSky()),
                Transform.translate(
                  offset: Offset(0, (1 - rise) * (c.body.height + c.view.height * .1)),
                  child: Transform(
                    transform: camera,
                    child: Stack(
                      children: [
                        _CabinetBody(c: c, lights: lights),
                        // The real arcade page, small, inside the screen.
                        Positioned.fromRect(
                          rect: c.screen,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10 * (1 - zoom)),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                const ColoredBox(color: Colors.black),
                                Opacity(
                                  opacity: screenOn,
                                  child: FittedBox(
                                    fit: BoxFit.fill,
                                    child: SizedBox.fromSize(size: c.view, child: child),
                                  ),
                                ),
                                // Glass glare that fades as we pass through.
                                IgnorePointer(
                                  child: Opacity(
                                    opacity: (1 - zoom) * .5,
                                    child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)],
                                          stops: [0, .35, 1],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Pip rides on top, waving.
                        Positioned(
                          left: c.body.center.dx - c.width * .26,
                          top: c.body.top - c.width * .36,
                          width: c.width * .52,
                          height: c.width * .4,
                          child: Opacity(
                            opacity: 1 - zoom,
                            child: PipDeskCompanion(
                              mood: lights > .1 ? PipMood.excited : PipMood.happy,
                              width: c.width * .52,
                              height: c.width * .4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: widget.child,
      );
    });
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

/// The machine: purple cabinet with neon trim, a marquee whose bulbs light
/// in a chase and letters light one by one, and a control panel.
class _CabinetBody extends StatelessWidget {
  final _Cabinet c;
  final double lights;
  const _CabinetBody({required this.c, required this.lights});

  static const _title = 'PIP ARCADE';

  @override
  Widget build(BuildContext context) {
    final w = c.width;
    return Stack(
      children: [
        Positioned.fromRect(
          rect: c.body,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF3A2A7A), Color(0xFF231A52), Color(0xFF15102F)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(w * .08), bottom: Radius.circular(w * .03)),
              border: Border.all(color: Color.lerp(Arcade.violet.withValues(alpha: .4), Arcade.violet, lights)!, width: 3),
              boxShadow: Arcade.boxGlow(Arcade.violet, strength: .3 + .9 * lights),
            ),
          ),
        ),
        Positioned.fromRect(
          rect: c.marquee,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0E0A22),
              borderRadius: BorderRadius.circular(w * .04),
              border: Border.all(color: Arcade.amber.withValues(alpha: .25 + .75 * lights), width: 2),
            ),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _BulbsPainter(lights))),
                Center(
                  child: FittedBox(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * .08),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, ch) in _title.split('').indexed)
                            _Letter(ch, on: Curves.easeOut.transform(_span(lights, .15 + i * .07, .3 + i * .07))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned.fromRect(
          rect: c.screen.inflate(w * .025),
          child: DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFF07060F), borderRadius: BorderRadius.circular(w * .04)),
          ),
        ),
        Positioned.fromRect(rect: c.panel, child: CustomPaint(painter: _PanelPainter(lights))),
      ],
    );
  }
}

class _Letter extends StatelessWidget {
  final String ch;
  final double on;
  const _Letter(this.ch, {required this.on});

  @override
  Widget build(BuildContext context) => Text(
        ch,
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: Color.lerp(const Color(0xFF3A3020), Arcade.amber, on),
          shadows: on > 0 ? Arcade.glow(Arcade.amber, strength: on * 1.3) : null,
        ),
      );
}

/// A ring of bulbs around the marquee that light one after another.
class _BulbsPainter extends CustomPainter {
  final double lights;
  _BulbsPainter(this.lights);

  @override
  void paint(Canvas canvas, Size s) {
    const n = 22;
    final inset = s.shortestSide * .12;
    final r = Rect.fromLTRB(inset, inset, s.width - inset, s.height - inset);
    final perimeter = 2 * (r.width + r.height);
    for (var i = 0; i < n; i++) {
      var d = perimeter * i / n;
      final Offset p;
      if (d < r.width) {
        p = Offset(r.left + d, r.top);
      } else if ((d -= r.width) < r.height) {
        p = Offset(r.right, r.top + d);
      } else if ((d -= r.height) < r.width) {
        p = Offset(r.right - d, r.bottom);
      } else {
        p = Offset(r.left, r.bottom - (d - r.width));
      }
      final on = (lights * n - i).clamp(0.0, 1.0);
      final color = Color.lerp(const Color(0xFF3A3020), i.isEven ? Arcade.amber : Arcade.pink, on)!;
      if (on > 0) {
        canvas.drawCircle(p, s.shortestSide * .07, Paint()
          ..color = color.withValues(alpha: .5 * on)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      }
      canvas.drawCircle(p, s.shortestSide * .035, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_BulbsPainter o) => o.lights != lights;
}

/// Joystick and three buttons that light with the marquee.
class _PanelPainter extends CustomPainter {
  final double lights;
  _PanelPainter(this.lights);

  @override
  void paint(Canvas canvas, Size s) {
    final deck = RRect.fromRectAndRadius(Rect.fromLTWH(s.width * .04, s.height * .1, s.width * .92, s.height * .8), Radius.circular(s.height * .2));
    canvas.drawRRect(deck, Paint()..color = const Color(0xFF120E28));
    final stick = Offset(s.width * .25, s.height * .52);
    canvas.drawCircle(stick, s.height * .2, Paint()..color = const Color(0xFF2A2350));
    canvas.drawLine(stick, stick.translate(0, -s.height * .28), Paint()
      ..color = const Color(0xFF8C97B8)
      ..strokeWidth = s.height * .06
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(stick.translate(0, -s.height * .3), s.height * .13, Paint()..color = Color.lerp(const Color(0xFF552233), Arcade.pink, lights)!);
    for (final (i, color) in [Arcade.amber, Arcade.teal, Arcade.violet].indexed) {
      final p = Offset(s.width * (.55 + i * .14), s.height * (.5 - (i == 1 ? .08 : 0)));
      final on = _span(lights, .4 + i * .15, .6 + i * .15);
      if (on > 0) {
        canvas.drawCircle(p, s.height * .2, Paint()
          ..color = color.withValues(alpha: .45 * on)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
      canvas.drawCircle(p, s.height * .12, Paint()..color = Color.lerp(const Color(0xFF2A2350), color, on)!);
    }
  }

  @override
  bool shouldRepaint(_PanelPainter o) => o.lights != lights;
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
              Opacity(
                opacity: leave,
                child: Transform.translate(offset: Offset(0, 60 * (1 - leave)), child: child),
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
