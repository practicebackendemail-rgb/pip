import 'package:flutter/widgets.dart';

/// Centralized Motion Design Tokens adhering to mobile motion specialist directives.
///
/// Rules:
/// - Screen transitions: <= 500ms
/// - Modals & drawers: <= 300ms
/// - Micro-interactions: <= 160ms
/// - Zero magic numbers. GPU properties only (opacity, scale, translate).
class AppMotionTokens {
  AppMotionTokens._();

  // Durations
  static const Duration micro = Duration(milliseconds: 140);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 280);
  static const Duration screen = Duration(milliseconds: 400);

  // Easing Curves
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeIn = Curves.easeInCubic;
  static const Curve standard = Curves.easeInOutCubic;
  static const Curve bounce = Curves.elasticOut;

  /// Checks system Reduce Motion accessibility preference.
  static bool shouldReduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  /// Returns effective duration, bypassing motion entirely if Reduce Motion is on.
  static Duration resolveDuration(BuildContext context, Duration duration) {
    return shouldReduceMotion(context) ? Duration.zero : duration;
  }
}
