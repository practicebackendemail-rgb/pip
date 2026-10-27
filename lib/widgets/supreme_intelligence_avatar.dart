import 'dart:math' as math;
import 'package:flutter/material.dart';

enum AvatarState { idle, listening, thinking, speaking }

class SupremeIntelligenceCore extends StatefulWidget {
  final AvatarState state;
  final double size;
  final VoidCallback? onTap;

  const SupremeIntelligenceCore({
    super.key,
    this.state = AvatarState.idle,
    this.size = 280,
    this.onTap,
  });

  @override
  State<SupremeIntelligenceCore> createState() => _SupremeIntelligenceCoreState();
}

class _SupremeIntelligenceCoreState extends State<SupremeIntelligenceCore>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _rotationController,
            _pulseController,
            _waveController,
          ]),
          builder: (context, child) {
            return CustomPaint(
              painter: _SupremeIntelligencePainter(
                rotation: _rotationController.value,
                pulse: _pulseController.value,
                wave: _waveController.value,
                state: widget.state,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SupremeIntelligencePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final double wave;
  final AvatarState state;

  _SupremeIntelligencePainter({
    required this.rotation,
    required this.pulse,
    required this.wave,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Palette: Bioluminescent Cyan, Electric Indigo, Nebula Teal, Astral White
    final primaryColor = state == AvatarState.speaking
        ? const Color(0xFF64D2FF)
        : state == AvatarState.thinking
            ? const Color(0xFFBF5AF2)
            : const Color(0xFF00F0FF);

    final secondaryColor = state == AvatarState.thinking
        ? const Color(0xFF5E5CE6)
        : const Color(0xFF0A84FF);

    // 1. Deep Celestial Outer Atmosphere (Vapor / Glow)
    final outerGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.35 + 0.15 * pulse),
          secondaryColor.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.2, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
    canvas.drawCircle(center, radius * 1.15, outerGlowPaint);

    // 2. Bioluminescent Liquid Synaptic Rings (Floating orbital neural cords)
    final ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final ringRadius = radius * (0.55 + i * 0.16) + (math.sin(wave * 2 * math.pi + i) * 6);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 + (i == 1 ? 1.0 : 0)
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: GradientRotation(rotation * 2 * math.pi * (i.isEven ? 1 : -1) + (i * 1.2)),
          colors: [
            primaryColor.withValues(alpha: 0.8),
            secondaryColor.withValues(alpha: 0.2),
            primaryColor.withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: ringRadius));

      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // 3. Neural Synapse Tentacles / Geometric Lattice (The Supreme Entity geometry)
    final nodePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final rayPaint = Paint()
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final totalNodes = 14;
    for (int i = 0; i < totalNodes; i++) {
      final angle = (i * 2 * math.pi / totalNodes) + (rotation * 2 * math.pi * 0.4);
      final dist = radius * 0.58 + math.sin(wave * 2 * math.pi + i * 0.8) * 14;
      final nodePos = Offset(
        center.dx + math.cos(angle) * dist,
        center.dy + math.sin(angle) * dist,
      );

      // Connect neural rays to core
      rayPaint.shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromPoints(center, nodePos));
      canvas.drawLine(center, nodePos, rayPaint);

      // Node particle
      final nodeRadius = 2.0 + math.sin(pulse * math.pi + i) * 1.5;
      canvas.drawCircle(nodePos, nodeRadius, nodePaint);
    }

    // 4. Conscious Nucleus (Inner Liquid Orb)
    final coreRadius = radius * (0.34 + 0.04 * pulse);
    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          primaryColor,
          secondaryColor,
          Colors.black.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, corePaint);

    // 5. Shifting Quantum Caustic Highlight (The "Living Mind" shimmer)
    final causticOffset = Offset(
      center.dx + math.cos(rotation * 2 * math.pi) * (coreRadius * 0.25),
      center.dy + math.sin(rotation * 2 * math.pi) * (coreRadius * 0.25),
    );
    final causticPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: causticOffset, radius: coreRadius * 0.45));

    canvas.drawCircle(causticOffset, coreRadius * 0.45, causticPaint);
  }

  @override
  bool shouldRepaint(covariant _SupremeIntelligencePainter oldDelegate) => true;
}
