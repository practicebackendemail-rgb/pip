import 'package:flutter/material.dart';
import 'pip_theme.dart';

/// Legacy names kept so older widgets pick up Pip's palette. New code should
/// use [PipColors] and [PipTheme] directly.
class AppleTheme {
  static const Color backgroundDark = PipColors.background;
  static const Color surfaceDark = PipColors.surface;
  static const Color cardDark = PipColors.card;
  static const Color borderDark = PipColors.border;

  static const Color accentBlue = PipColors.amber;
  static const Color accentPurple = PipColors.rust;
  static const Color accentIndigo = PipColors.rust;
  static const Color accentTeal = PipColors.amber;
  static const Color accentGreen = PipColors.ok;
  static const Color accentOrange = PipColors.warn;
  static const Color accentRed = PipColors.danger;

  static const Color textPrimary = PipColors.ink;
  static const Color textSecondary = PipColors.muted;
  static const Color textTertiary = PipColors.faint;

  static ThemeData get darkTheme => PipTheme.dark;
}
