import 'package:flutter/material.dart';
import 'pip_tokens.dart';

export 'pip_tokens.dart';

/// Pip's palette, taken from the character design (amber body, rust trim,
/// slate screens). Every screen should use these instead of raw colors.
class PipColors {
  static const Color background = Color(0xFF12171A);
  static const Color surface = Color(0xFF161C1F);
  static const Color card = Color(0xFF1B2225);
  static const Color chip = Color(0xFF232C30);
  static const Color border = Color(0xFF3B4A4F);
  static const Color borderSoft = Color(0xFF2A3236);

  static const Color ink = Color(0xFFE8ECEB);
  static const Color muted = Color(0xFF9FB0B3);
  static const Color faint = Color(0xFF6E7F83);

  static const Color amber = Color(0xFFE2A826);
  static const Color amberSoft = Color(0xFFF3C95A);
  static const Color rust = Color(0xFFB4602A);
  static const Color rustDeep = Color(0xFF7A3D14);
  static const Color onAmber = Color(0xFF1B1409);

  static const Color ok = Color(0xFF6FBF73);
  static const Color info = Color(0xFF4AA3FF);
  static const Color warn = Color(0xFFF2B134);
  static const Color danger = Color(0xFFE5604D);

  static const Color wall = Color(0xFFEBE3D5);
}

/// Spacing and radii shared by all screens.
class PipSpace {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
  static const double radius = 14, radiusLg = 20, pill = 999;

  /// Width at which layouts switch from phone stacking to desktop panes.
  static const double wideBreakpoint = 900;

  static bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= wideBreakpoint;
}

class PipTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: PipColors.amber,
      onPrimary: PipColors.onAmber,
      secondary: PipColors.rust,
      onSecondary: PipColors.ink,
      surface: PipColors.surface,
      onSurface: PipColors.ink,
      error: PipColors.danger,
      outline: PipColors.border,
      outlineVariant: PipColors.borderSoft,
    );
    final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(PipSpace.pill));
    const textTheme = TextTheme(
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: PipColors.ink, height: 1.25),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: PipColors.ink),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: PipColors.ink),
      bodyLarge: TextStyle(fontSize: 16, color: PipColors.ink, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, color: PipColors.ink, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, color: PipColors.muted, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .2),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: PipColors.amber, letterSpacing: 1.1),
    );

    return ThemeData(
      extensions: const [PipTokens.dark],
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: PipColors.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: PipColors.ink,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: PipColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PipColors.amber,
          foregroundColor: PipColors.onAmber,
          minimumSize: const Size(64, 48),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PipColors.ink,
          minimumSize: const Size(64, 48),
          side: const BorderSide(color: PipColors.border),
          shape: pill,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: PipColors.amber, textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PipColors.chip,
        hintStyle: const TextStyle(color: PipColors.faint),
        labelStyle: const TextStyle(color: PipColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PipSpace.radius),
          borderSide: const BorderSide(color: PipColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PipSpace.radius),
          borderSide: const BorderSide(color: PipColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PipSpace.radius),
          borderSide: const BorderSide(color: PipColors.amber, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? PipColors.onAmber : PipColors.muted),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? PipColors.amber : PipColors.chip),
        trackOutlineColor: const WidgetStatePropertyAll(PipColors.border),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: PipColors.amber,
        inactiveTrackColor: PipColors.chip,
        thumbColor: PipColors.amber,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: PipColors.amber,
        textColor: PipColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: PipSpace.lg),
      ),
      dividerTheme: const DividerThemeData(color: PipColors.borderSoft, space: 1, thickness: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: PipColors.chip,
        contentTextStyle: TextStyle(color: PipColors.ink),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PipColors.surface,
        showDragHandle: true,
        dragHandleColor: PipColors.border,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: PipColors.surface,
        indicatorColor: PipColors.chip,
        selectedIconTheme: IconThemeData(color: PipColors.amber),
        unselectedIconTheme: IconThemeData(color: PipColors.muted),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(color: PipColors.chip, borderRadius: BorderRadius.all(Radius.circular(8))),
        textStyle: TextStyle(color: PipColors.ink, fontSize: 12),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
