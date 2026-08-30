import 'package:flutter/material.dart';

/// Dark agricultural-machinery style palette + theme.
class AppTheme {
  AppTheme._();

  static const Color bg = Color(0xFF0B130E); // near-black green
  static const Color surface = Color(0xFF15221A);
  static const Color surfaceLight = Color(0xFF1E3024);
  static const Color border = Color(0xFF2A4232);
  static const Color accent = Color(0xFF3DDC84); // spray green
  static const Color amber = Color(0xFFFFB300);
  static const Color danger = Color(0xFFFF5252);
  static const Color text = Color(0xFFE8F1EA);
  static const Color textDim = Color(0xFF8FA695);

  static ThemeData dark() {
    final ThemeData base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: amber,
        surface: surface,
        error: danger,
      ),
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        height: 72,
        indicatorColor: accent.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? accent : textDim,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : textDim,
          ),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: border,
        overlayColor: accent.withValues(alpha: 0.15),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent.withValues(alpha: 0.4)
              : border,
        ),
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
    );
  }
}
