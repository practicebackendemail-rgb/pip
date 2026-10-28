import 'package:flutter/painting.dart';

/// Pip's colours and the paints, shapes and label built from them. Created
/// once and reused every frame; Pip is always drawn in a fixed 320 x 240
/// space, so even the shapes and shadow gradients can be precomputed.
abstract final class PipPaints {
  static const gold = Color(0xFFDCA21E);
  static const rust = Color(0xFFA4551F);
  static const darkRust = Color(0xFF5A2D0F);
  static const arm = Color(0xFF8A4A1C);
  static const track = Color(0xFF2B2F31);
  static const trackRib = Color(0xFF4A5053);
  static const hub = Color(0xFF3A3F43);
  static const badge = Color(0xFFE4E8E6);
  static const badgeLine = Color(0xFF4F5D61);
  static const console = Color(0xFF1C2427);
  static const waveLed = Color(0xFFFFD77A);
  static const lid = Color(0xFFC0821F);
  static const lensFrame = Color(0xFF1F2A2E);
  static const lens = Color(0xFF151A1C);
  static const lensRing = Color(0xFF24363C);
  static const pupil = Color(0xFF05080A);
  static const sheen = Color(0xFFF3C95A);
  static const stamp = Color(0xFF7A3D14);

  static Paint fill(Color c) => Paint()..color = c;
  static Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  static final goldFill = fill(gold);
  static final rustFill = fill(rust);
  static final armFill = fill(arm);
  static final trackFill = fill(track);
  static final hubFill = fill(hub);
  static final ribFill = fill(trackRib);
  static final badgeFill = fill(badge);
  static final consoleFill = fill(console);
  static final sheenFill = fill(sheen);
  static final lidFill = fill(lid);
  static final lensFrameFill = fill(lensFrame);
  static final lensFill = fill(lens);
  static final pupilFill = fill(pupil);
  static final glintBig = fill(const Color(0xEBFFFFFF));
  static final glintSmall = fill(const Color(0x8CFFFFFF));

  static final rustStroke = stroke(rust, 3);
  static final darkRustStroke = stroke(darkRust, 3);
  static final housingStroke = stroke(rust, 4.5);
  static final sheenStroke = stroke(sheen, 4.5);
  static final ribStroke = stroke(trackRib, 2.5);
  static final hubStroke = stroke(trackRib, 2.5);
  static final badgeLineStroke = stroke(badgeLine, 2);
  static final neckStroke = stroke(darkRust, 2);
  static final lensRingStroke = stroke(lensRing, 2);
  static final waveStroke = stroke(waveLed, 2);

  /// The LED colour changes with mood, so its paint is reused and recoloured.
  static final ledFill = Paint();

  /// Soft contact shadows: radial gradients instead of a per-frame blur.
  static Paint _shadow(Rect r) => Paint()
    ..shader = const RadialGradient(
      colors: [Color(0x55000000), Color(0x00000000)],
    ).createShader(r);
  static const shadowLeft = Rect.fromLTWH(24, 218, 76, 22);
  static const shadowRight = Rect.fromLTWH(220, 218, 76, 22);
  static const shadowMid = Rect.fromLTWH(80, 222, 160, 18);
  static final shadowLeftPaint = _shadow(shadowLeft);
  static final shadowRightPaint = _shadow(shadowRight);
  static final shadowMidPaint = _shadow(shadowMid);

  static final housingSheen = Path()
    ..moveTo(-32, -38)
    ..quadraticBezierTo(0, -47, 32, -38);

  static final lensClip = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 38));

  /// The "PIP" stamp, laid out once.
  static final TextPainter stampLabel = TextPainter(
    text: const TextSpan(
      text: 'PIP',
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 2.2, color: stamp),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
}
