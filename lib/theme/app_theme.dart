import 'package:flutter/material.dart';

/// Color tokens carried over 1:1 from the web prototype, so the native
/// app reads as the same product rather than a re-skin.
class StaxColors {
  StaxColors._();

  // Light
  static const paper = Color(0xFFF3F4F7);
  static const paperCard = Color(0xFFFFFFFF);
  static const line = Color(0xFFE1E1E8);
  static const indigo = Color(0xFF40356B);
  static const indigoSoft = Color(0xFFEEEBF6);
  static const teal = Color(0xFF12A594);
  static const tealHover = Color(0xFF0E8C7D);
  static const text = Color(0xFF1D1B26);
  static const textDim = Color(0xFF68667A);
  static const amber = Color(0xFFC4780A);
  static const red = Color(0xFFD14343);

  // Dark
  static const paperDark = Color(0xFF121017);
  static const paperCardDark = Color(0xFF1B1926);
  static const lineDark = Color(0xFF2E2B3D);
  static const indigoDark = Color(0xFF9A8CD6);
  static const indigoSoftDark = Color(0xFF252038);
  static const tealDark = Color(0xFF2BD9C4);
  static const textDark = Color(0xFFF0EFF5);
  static const textDimDark = Color(0xFF9997AC);
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: StaxColors.paper,
      colorScheme: const ColorScheme.light(
        primary: StaxColors.indigo,
        secondary: StaxColors.teal,
        surface: StaxColors.paperCard,
        onSurface: StaxColors.text,
      ),
      fontFamily: 'Inter',
      textTheme: _textTheme(StaxColors.text, StaxColors.textDim),
      cardColor: StaxColors.paperCard,
      dividerColor: StaxColors.line,
      appBarTheme: const AppBarTheme(
        backgroundColor: StaxColors.paper,
        foregroundColor: StaxColors.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaxColors.teal,
          foregroundColor: const Color(0xFF062521),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: StaxColors.paperDark,
      colorScheme: const ColorScheme.dark(
        primary: StaxColors.indigoDark,
        secondary: StaxColors.tealDark,
        surface: StaxColors.paperCardDark,
        onSurface: StaxColors.textDark,
      ),
      fontFamily: 'Inter',
      textTheme: _textTheme(StaxColors.textDark, StaxColors.textDimDark),
      cardColor: StaxColors.paperCardDark,
      dividerColor: StaxColors.lineDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: StaxColors.paperDark,
        foregroundColor: StaxColors.textDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: StaxColors.tealDark,
          foregroundColor: const Color(0xFF062521),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color text, Color dim) {
    return TextTheme(
      titleLarge: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w600, color: text, fontSize: 20),
      titleMedium: TextStyle(fontFamily: 'Fraunces', fontWeight: FontWeight.w500, color: text, fontSize: 17),
      bodyMedium: TextStyle(color: text, fontSize: 14),
      bodySmall: TextStyle(color: dim, fontSize: 12.5),
      labelSmall: TextStyle(fontFamily: 'JetBrainsMono', color: dim, fontSize: 11),
    );
  }
}
