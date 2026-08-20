import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// LiftOff Design System — Typography
/// Clean, high-trust sans-serif (Inter/Outfit) for P2P Mobility.
class AppTextStyles {
  AppTextStyles._();

  // ─── Display ───
  static TextStyle display = GoogleFonts.inter(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.midnightBlue,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle displaySmall = GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.midnightBlue,
    letterSpacing: -0.3,
    height: 1.2,
  );

  // ─── Headings ───
  static TextStyle h1 = GoogleFonts.inter(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.midnightBlue,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle h2 = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.midnightBlue,
    height: 1.3,
  );

  static TextStyle h3 = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.midnightBlue,
    height: 1.4,
  );

  // ─── Body ───
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.midnightBlue,
    height: 1.5,
  );

  static TextStyle body = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.deepSlate,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.mediumGray,
    height: 1.5,
  );

  // ─── Labels & Trust Badges ───
  static TextStyle label = GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.midnightBlue,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static TextStyle caption = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGray,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static TextStyle verifiedPill = GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.verifiedGreen,
    letterSpacing: 0.2,
  );

  static TextStyle matchBadge = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.primaryTealDark,
    letterSpacing: 0.3,
  );

  // ─── Fares & Prices ───
  static TextStyle fareAmount = GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.midnightBlue,
    letterSpacing: -0.3,
  );

  static TextStyle fareUnit = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.mediumGray,
  );

  // ─── Buttons ───
  static TextStyle buttonPrimary = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.midnightBlue,
    letterSpacing: 0.3,
  );

  static TextStyle buttonDark = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: 0.3,
  );
}
