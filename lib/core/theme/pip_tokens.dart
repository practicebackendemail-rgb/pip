import 'package:flutter/material.dart';
import 'app_motion_tokens.dart';
import 'pip_theme.dart';

/// Semantic colours. Widgets ask for a role (surface, accent, danger), never
/// a hex value, so a light theme later only means a second instance of this.
@immutable
class PipColorTokens {
  final Color background, surface, card, chip, border, borderSoft;
  final Color text, textMuted, textFaint;
  final Color accent, accentSoft, onAccent, secondary, secondaryDeep;
  final Color success, info, warning, danger;

  const PipColorTokens({
    required this.background,
    required this.surface,
    required this.card,
    required this.chip,
    required this.border,
    required this.borderSoft,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.secondary,
    required this.secondaryDeep,
    required this.success,
    required this.info,
    required this.warning,
    required this.danger,
  });

  static const dark = PipColorTokens(
    background: PipColors.background,
    surface: PipColors.surface,
    card: PipColors.card,
    chip: PipColors.chip,
    border: PipColors.border,
    borderSoft: PipColors.borderSoft,
    text: PipColors.ink,
    textMuted: PipColors.muted,
    textFaint: PipColors.faint,
    accent: PipColors.amber,
    accentSoft: PipColors.amberSoft,
    onAccent: PipColors.onAmber,
    secondary: PipColors.rust,
    secondaryDeep: PipColors.rustDeep,
    success: PipColors.ok,
    info: PipColors.info,
    warning: PipColors.warn,
    danger: PipColors.danger,
  );
}

/// Spacing scale and corner radii.
@immutable
class PipSpaceTokens {
  final double xs, sm, md, lg, xl, xxl;
  final double radius, radiusLg, pill;
  final double wideBreakpoint;

  const PipSpaceTokens({
    this.xs = PipSpace.xs,
    this.sm = PipSpace.sm,
    this.md = PipSpace.md,
    this.lg = PipSpace.lg,
    this.xl = PipSpace.xl,
    this.xxl = PipSpace.xxl,
    this.radius = PipSpace.radius,
    this.radiusLg = PipSpace.radiusLg,
    this.pill = PipSpace.pill,
    this.wideBreakpoint = PipSpace.wideBreakpoint,
  });
}

/// Motion durations and curves, re-exported from [AppMotionTokens] so all
/// motion goes through one place.
@immutable
class PipMotionTokens {
  const PipMotionTokens();

  Duration get micro => AppMotionTokens.micro;
  Duration get fast => AppMotionTokens.fast;
  Duration get medium => AppMotionTokens.medium;
  Duration get screen => AppMotionTokens.screen;
  Curve get easeOut => AppMotionTokens.easeOut;
  Curve get easeIn => AppMotionTokens.easeIn;
  Curve get standard => AppMotionTokens.standard;
}

/// Pip's design tokens, attached to the theme. Read with `context.tokens`.
@immutable
class PipTokens extends ThemeExtension<PipTokens> {
  final PipColorTokens colors;
  final PipSpaceTokens space;
  final PipMotionTokens motion;

  const PipTokens({
    this.colors = PipColorTokens.dark,
    this.space = const PipSpaceTokens(),
    this.motion = const PipMotionTokens(),
  });

  static const dark = PipTokens();

  @override
  PipTokens copyWith({PipColorTokens? colors, PipSpaceTokens? space, PipMotionTokens? motion}) =>
      PipTokens(colors: colors ?? this.colors, space: space ?? this.space, motion: motion ?? this.motion);

  /// Tokens are discrete (one dark palette today), so no interpolation.
  @override
  PipTokens lerp(covariant PipTokens? other, double t) => t < .5 ? this : (other ?? this);
}

extension PipTokensContext on BuildContext {
  /// Design tokens for the current theme.
  PipTokens get tokens => Theme.of(this).extension<PipTokens>() ?? PipTokens.dark;

  /// True when the system asks for reduced motion.
  bool get reduceMotion => AppMotionTokens.shouldReduceMotion(this);

  /// Phone vs desktop/tablet layout switch.
  bool get isWide => MediaQuery.sizeOf(this).width >= tokens.space.wideBreakpoint;

  /// [duration], or zero when reduce motion is on.
  Duration motion(Duration duration) => AppMotionTokens.resolveDuration(this, duration);
}
