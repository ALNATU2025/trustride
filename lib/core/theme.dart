import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand tokens taken from the TrustRide logo: deep navy into fresh green.
class TR {
  static const navy = Color(0xFF0B2A5B);
  static const navyDeep = Color(0xFF071C3F);
  static const navySoft = Color(0xFF16407E);
  static const green = Color(0xFF1F7A32);
  static const greenBright = Color(0xFF5BBF2A);
  static const greenTint = Color(0xFFEAF5EC);
  static const ink = Color(0xFF0F1B2D);
  static const muted = Color(0xFF4A5A70);
  static const subtle = Color(0xFF6B7A8E);
  static const line = Color(0xFFE3E8EE);
  static const border = Color(0xFFD8DEE6);
  static const surface = Color(0xFFF6F8FA);
  static const field = Color(0xFFF1F4F8);
  static const land = Color(0xFFEEF1EC);
  static const park = Color(0xFFDCEBD8);
  static const sea = Color(0xFFCFE3F2);
  static const gold = Color(0xFFE8A317);
  static const danger = Color(0xFFC62828);
  static const dangerTint = Color(0xFFFDECEC);
  static const amberTint = Color(0xFFFFF4DB);
  static const amberInk = Color(0xFF8A5A00);
  static const orangeMoney = Color(0xFFF47B20);
  static const afrimoney = Color(0xFF7A2C8F);

  static const brandGradient = LinearGradient(
    colors: [navy, Color(0xFF0F4A6E), green],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> shadow([double strength = 1]) => [
        BoxShadow(
          color: navy.fade(0.10 * strength),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: navy.fade(0.04 * strength),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static String le(num amount, {bool decimals = false}) {
    final fixed = amount.toStringAsFixed(decimals ? 2 : 0);
    final parts = fixed.split('.');
    final whole = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return 'Le $whole${parts.length > 1 ? '.${parts[1]}' : ''}';
  }
}

extension ColorFade on Color {
  /// Opacity helper that works across Flutter versions.
  Color fade(double opacity) => withAlpha((opacity.clamp(0, 1) * 255).round());
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: TR.navy,
      primary: TR.navy,
      secondary: TR.green,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    splashFactory: InkSparkle.splashFactory,
  );
  final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
    bodyColor: TR.ink,
    displayColor: TR.ink,
  );
  return base.copyWith(
    textTheme: text,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TR.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TR.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TR.navy, width: 2),
      ),
      labelStyle: const TextStyle(color: TR.muted),
      hintStyle: const TextStyle(color: TR.subtle),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TR.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Short-hand text styles used across screens.
class TS {
  static TextStyle h1 = GoogleFonts.plusJakartaSans(
      fontSize: 30, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.6, color: TR.ink);
  static TextStyle h2 = GoogleFonts.plusJakartaSans(
      fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: TR.ink);
  static TextStyle h3 = GoogleFonts.plusJakartaSans(
      fontSize: 18, fontWeight: FontWeight.w800, color: TR.ink);
  static TextStyle body = GoogleFonts.plusJakartaSans(
      fontSize: 15, height: 1.5, color: TR.muted);
  static TextStyle label = GoogleFonts.plusJakartaSans(
      fontSize: 15, fontWeight: FontWeight.w700, color: TR.ink);
  static TextStyle small = GoogleFonts.plusJakartaSans(
      fontSize: 13, color: TR.muted);
  static TextStyle caps = GoogleFonts.plusJakartaSans(
      fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: TR.muted);
}
