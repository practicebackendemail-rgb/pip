import 'package:flutter/painting.dart';

/// Everything that changes on Pip from frame to frame. One mutable instance
/// is written by the pose controller and read by the painter, so a frame
/// costs no allocations and no widget rebuilds.
class PipPose {
  double lid; // top eyelid, 0 open … 1 closed
  double low; // lower eyelid, 0 … 1 (smile squint)
  double tilt; // eye housing tilt, degrees
  double px, py; // pupil offset, -1 … 1
  double s; // lens scale
  double head; // head rotation, degrees
  double bob; // head vertical offset, px in 320-space
  double armLeft, armRight; // degrees
  Color led;

  /// Whole-body lean while rolling, degrees (+ = leaning right).
  double lean;

  /// Squash and stretch: 1 = rest, < 1 squashed, > 1 stretched.
  double squash;

  /// Wheel rotation, radians; advances with travel speed.
  double treadPhase;

  /// Seconds since start; drives the chest waveform.
  double time;
  bool talking;

  PipPose({
    this.lid = 0,
    this.low = 0,
    this.tilt = 14,
    this.px = 0,
    this.py = 0,
    this.s = 1,
    this.head = 0,
    this.bob = 0,
    this.armLeft = 3,
    this.armRight = 3,
    this.led = const Color(0xFF6FBF73),
    this.lean = 0,
    this.squash = 1,
    this.treadPhase = 0,
    this.time = 0,
    this.talking = false,
  });
}
