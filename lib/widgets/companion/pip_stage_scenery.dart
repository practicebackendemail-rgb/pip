import 'dart:async';
import 'package:flutter/material.dart';
import 'pip_stage_scenery_painter.dart';

/// Full-screen ambient desk window backdrop that changes dynamically with local time.
class PipStageScenery extends StatefulWidget {
  final Widget child;

  const PipStageScenery({super.key, required this.child});

  @override
  State<PipStageScenery> createState() => _PipStageSceneryState();
}

class _PipStageSceneryState extends State<PipStageScenery> {
  late double _currentHour;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Re-evaluate scene lighting every 30 seconds
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    final hourDecimal = now.hour + (now.minute / 60.0);
    if (mounted) {
      setState(() => _currentHour = hourDecimal);
    } else {
      _currentHour = hourDecimal;
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Vector Window & Scenery Canvas
        Positioned.fill(
          child: CustomPaint(
            painter: PipStageSceneryPainter(hour: _currentHour),
          ),
        ),
        // 2. iOS-grade Frosted Ambient Gradient Scrim
        // Ensures top header controls and bottom action dock retain peak legibility
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.70),
                ],
                stops: const [0.0, 0.22, 0.65, 1.0],
              ),
            ),
          ),
        ),
        // 3. Foreground Content
        widget.child,
      ],
    );
  }
}
