import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// LiftOff Design System — Material 3 Theme Configuration
/// Clean, high-trust, eco-modern glassmorphic styling.
class AppTheme {
  AppTheme._();

  // ─── Floating Card Decoration ───
  static BoxDecoration get cardDecoration => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.borderGray, width: 1),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadowLight,
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
      BoxShadow(
        color: Color(0x05000000),
        blurRadius: 4,
        offset: Offset(0, 1),
      ),
    ],
  );

  // ─── High Trust Card (Emerald accent border) ───
  static BoxDecoration get verifiedCardDecoration => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.verifiedGreen.withAlpha(50), width: 1.5),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadowLight,
        blurRadius: 16,
        offset: Offset(0, 4),
      ),
    ],
  );

  // ─── Bottom Sheet Modal Decoration ───
  static BoxDecoration get bottomSheetDecoration => const BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.shadowHeavy,
        blurRadius: 32,
        offset: Offset(0, -6),
      ),
    ],
  );

  // ─── Selected Item Decoration ───
  static BoxDecoration selectedCardDecoration({Color? borderColor}) =>
      BoxDecoration(
        color: AppColors.primaryTealSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? AppColors.primaryTeal,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.tealGlow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      );

  // ─── Material Theme Data ───
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.softGray,
      primaryColor: AppColors.primaryTeal,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryTeal,
        onPrimary: AppColors.midnightBlue,
        secondary: AppColors.midnightBlue,
        onSecondary: AppColors.white,
        surface: AppColors.white,
        onSurface: AppColors.midnightBlue,
        error: AppColors.errorRed,
        onError: AppColors.white,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: AppColors.midnightBlue),
        titleTextStyle: TextStyle(
          color: AppColors.midnightBlue,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderGray),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: AppColors.midnightBlue,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
