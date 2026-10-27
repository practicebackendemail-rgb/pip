import 'package:flutter/material.dart';

enum PipMood { idle, listening, thinking, talking, happy, unsure, sleepy, sleeping, excited, sad, laughing, blinking }

class PipParams {
  final double lid, low, tilt, px, py, s, head, bob, al, ar;
  final Color led;

  const PipParams({
    this.lid = 0,
    this.low = 0,
    this.tilt = 14,
    this.px = 0,
    this.py = 0,
    this.s = 1.0,
    this.head = 0,
    this.bob = 0,
    this.al = 3,
    this.ar = 3,
    this.led = const Color(0xFF6FBF73),
  });

  PipParams copyWith({
    double? lid, double? low, double? tilt, double? px, double? py,
    double? s, double? head, double? bob, double? al, double? ar, Color? led,
  }) => PipParams(
    lid: lid ?? this.lid,
    low: low ?? this.low,
    tilt: tilt ?? this.tilt,
    px: px ?? this.px,
    py: py ?? this.py,
    s: s ?? this.s,
    head: head ?? this.head,
    bob: bob ?? this.bob,
    al: al ?? this.al,
    ar: ar ?? this.ar,
    led: led ?? this.led,
  );

  static const PipParams idle = PipParams();
  static const PipParams listening = PipParams(s: 1.1, py: -0.2, head: 3, tilt: 9, al: 12, ar: 12, led: Color(0xFF4AA3FF));
  static const PipParams thinking = PipParams(lid: 0.28, low: 0.08, px: -0.8, py: -0.9, head: -7, tilt: 20, al: 28, ar: 3, led: Color(0xFFF2B134));
  static const PipParams talking = PipParams(s: 1.03);
  static const PipParams happy = PipParams(low: 0.5, py: -0.2, s: 1.05, head: 4, tilt: 5, al: 40, ar: 40);
  static const PipParams unsure = PipParams(lid: 0.12, px: 0.5, py: 0.3, head: -5, tilt: 26, al: 20, ar: 2, led: Color(0xFFE07A4A));
  static const PipParams sleepy = PipParams(lid: 0.65, low: 0.1, py: 0.5, head: 6, s: 0.97, tilt: 22, al: -5, ar: -5, led: Color(0xFF8A8F93));
  static const PipParams sleeping = PipParams(lid: 0.96, low: 0.15, py: 0.7, head: 9, s: 0.94, tilt: 26, al: -10, ar: -10, bob: 5, led: Color(0xFF2B2F31));
  static const PipParams excited = PipParams(s: 1.15, low: 0.35, py: -0.3, tilt: 8, al: 45, ar: 45);
  static const PipParams sad = PipParams(lid: 0.42, low: 0.0, py: 0.4, head: -8, tilt: 28, al: -12, ar: -12, bob: 3, led: Color(0xFF7C83FD));
  static const PipParams laughing = PipParams(low: 0.65, py: -0.25, s: 1.12, head: 5, tilt: 4, al: 45, ar: 45, led: Color(0xFFFFD700));
}
