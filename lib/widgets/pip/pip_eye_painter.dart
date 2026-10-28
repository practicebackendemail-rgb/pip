import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'pip_paints.dart';
import 'pip_pose.dart';

/// Draws one of Pip's binocular eyes at [center]. [side] is +1 for the left
/// eye and -1 for the right, mirroring the housing tilt.
void paintPipEye(Canvas canvas, Offset center, double side, PipPose pose) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(pose.tilt * side * math.pi / 180);

  // Housing, rim, and the light catching its top edge.
  final housing = RRect.fromRectAndRadius(const Rect.fromLTWH(-52, -46, 104, 92), const Radius.circular(34));
  canvas.drawRRect(housing, PipPaints.goldFill);
  canvas.drawRRect(housing, PipPaints.housingStroke);
  canvas.drawPath(PipPaints.housingSheen, PipPaints.sheenStroke);
  canvas.drawCircle(const Offset(-36, -30), 3.5, PipPaints.rustFill);
  canvas.drawCircle(const Offset(36, 30), 3.5, PipPaints.rustFill);
  canvas.drawCircle(Offset.zero, 42, PipPaints.lensFrameFill);

  // Lens contents are clipped to the lens and scale with interest.
  canvas.save();
  canvas.scale(pose.s, pose.s);
  canvas.clipPath(PipPaints.lensClip);
  canvas.drawCircle(Offset.zero, 38, PipPaints.lensFill);
  canvas.drawCircle(Offset.zero, 30, PipPaints.lensRingStroke);

  canvas.save();
  canvas.translate(pose.px * 11, pose.py * 8);
  canvas.drawCircle(Offset.zero, 19, PipPaints.pupilFill);
  canvas.drawCircle(const Offset(-7, -8), 6, PipPaints.glintBig);
  canvas.drawCircle(const Offset(6, 7), 2.5, PipPaints.glintSmall);
  canvas.restore();

  // Eyelids slide over the lens from above and below.
  canvas.drawRect(Rect.fromLTWH(-42, -110 + pose.lid * 76, 84, 72), PipPaints.lidFill);
  canvas.drawRect(Rect.fromLTWH(-42, 38 - pose.low * 76, 84, 72), PipPaints.lidFill);
  canvas.restore();

  canvas.restore();
}
