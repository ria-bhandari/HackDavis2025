import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // A trio of vibrant brand colors
  static const Color primary   = Color(0xFF00BFA6); // teal
  static const Color secondary = Color(0xFFFFC107); // amber
  static const Color accent    = Color(0xFF2962FF); // bright blue

  static ThemeData light() {
    final cs = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: Colors.black,
      tertiary: accent,
      onTertiary: Colors.white,
      background: const Color(0xFFF0F4F8),
      onBackground: Colors.black87,
      surface: Colors.white,
      onSurface: Colors.black87,
      error: Colors.redAccent,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.background,
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: cs.onBackground,
        displayColor: cs.onBackground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardTheme(
        color: cs.surface,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: cs.secondary.withOpacity(.32),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
