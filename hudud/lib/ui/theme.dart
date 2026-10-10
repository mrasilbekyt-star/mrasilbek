import 'package:flutter/material.dart';

/// The Hudud look: deep night blue, neon territory, violet accents.
abstract final class Palette {
  static const background = Color(0xFF070B12);
  static const surface = Color(0xFF0F1622);
  static const surfaceHigh = Color(0xFF172030);
  static const line = Color(0xFF243044);
  static const text = Color(0xFFEAF0F8);
  static const muted = Color(0xFF8A97AB);
  static const violet = Color(0xFF7C5CFF);
  static const gold = Color(0xFFFFD84D);
  static const danger = Color(0xFFFF4D6D);
  static const warning = Color(0xFFFFB020);

  static const proGradient = LinearGradient(
    colors: [Color(0xFFFFD84D), Color(0xFFFF8A3D), Color(0xFFFF4FD8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData hududTheme(Color accent) {
  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      primary: accent,
      secondary: Palette.violet,
      surface: Palette.surface,
    ),
    scaffoldBackgroundColor: Palette.background,
    useMaterial3: true,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.text, displayColor: Palette.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.background,
      foregroundColor: Palette.text,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: Palette.line,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Palette.background : Palette.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : Palette.surfaceHigh),
    ),
  );
}

/// Numbers that do not jump around as digits change.
const tabular = [FontFeature.tabularFigures()];

TextStyle bigNumber(double size, {Color color = Palette.text}) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: -0.5,
      color: color,
      fontFeatures: tabular,
    );

const caption = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
  color: Palette.muted,
);
