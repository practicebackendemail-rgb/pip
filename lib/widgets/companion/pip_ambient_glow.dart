import 'package:flutter/widgets.dart';

/// Ambient golden circular glow backdrop for Pip's stage.
class PipAmbientGlow extends StatelessWidget {
  const PipAmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -100,
      left: MediaQuery.of(context).size.width * 0.15,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              const Color(0xFFE2A826).withValues(alpha: 0.14),
              const Color(0x00000000),
            ],
          ),
        ),
      ),
    );
  }
}
