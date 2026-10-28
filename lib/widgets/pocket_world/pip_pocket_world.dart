import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'pocket_sky_painter.dart';

export 'pocket_island.dart';

/// One clock for the whole pocket world, so the sky's bird and Pip's eyes
/// agree on where things are.
final Stopwatch _worldClock = Stopwatch()..start();
double get pocketWorldTime => _worldClock.elapsedMicroseconds / 1e6;
double get pocketLocalHour {
  final now = DateTime.now();
  return now.hour + now.minute / 60.0;
}

/// Full-screen sky behind the stage (replaces the old desk window scene).
class PipPocketSky extends StatefulWidget {
  final Widget child;
  final bool overcast;

  const PipPocketSky({super.key, required this.child, this.overcast = false});

  @override
  State<PipPocketSky> createState() => _PipPocketSkyState();
}

class _PipPocketSkyState extends State<PipPocketSky> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    // ~30 fps is plenty for drifting clouds and saves battery.
    var last = 0.0;
    _ticker = createTicker((_) {
      final t = pocketWorldTime;
      if (t - last >= 1 / 30) {
        last = t;
        setState(() => _time = t);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: PocketSkyPainter(hour: pocketLocalHour, time: still ? 0 : _time, overcast: widget.overcast),
            ),
          ),
        ),
        // Light scrim top and bottom so header and dock stay readable.
        const Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x99000000)],
                  stops: [0, .2, .62, 1],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}
