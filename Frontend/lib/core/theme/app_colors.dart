import 'package:flutter/material.dart';

/// LiftOff Design System — True Brand Color Palette
///
/// Sustainable, Community-driven P2P Mobility theme.

class AppColors {
  AppColors._();

  // ─── Primary Brand (Electric Teal / Mint) ───

  static const Color primaryTeal = Color(0xFF00D294);

  static const Color primaryTealLight = Color(0xFF4EEDB2);

  static const Color primaryTealDark = Color(0xFF00A373);

  static const Color primaryTealSurface = Color(0xFFE6FAF4);

  // ─── Deep Midnight & Dark Surfaces ───

  static const Color midnightBlue = Color(0xFF0A1128);

  static const Color deepNavy = Color(0xFF101935);

  static const Color cardDark = Color(0xFF162040);

  static const Color deepSlate = Color(0xFF1C1C1C);

  static const Color darkGray = Color(0xFF2D2D2D);

  // ─── Text Colors ───

  /// Main text color for headings and important content.
  static const Color textPrimary = Color(0xFF111827);

  /// Secondary text color for descriptions, labels and subtitles.
  static const Color textSecondary = Color(0xFF6B7280);

  /// Light/muted text for less important information.
  static const Color textMuted = Color(0xFF9CA3AF);

  /// Text displayed on dark backgrounds.
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Text displayed on primary teal backgrounds.
  static const Color textOnPrimary = Color(0xFF0A1128);

  // ─── Neutrals & Backgrounds ───

  static const Color mediumGray = Color(0xFF6B7280);

  static const Color subtleGray = Color(0xFF9CA3AF);

  static const Color lightGray = Color(0xFFE5E7EB);

  static const Color borderGray = Color(0xFFF0F2F5);

  static const Color softGray = Color(0xFFF8FAFC);

  static const Color white = Color(0xFFFFFFFF);

  // ─── Semantic & Safety Badges ───

  static const Color verifiedGreen = Color(0xFF10B981);

  static const Color verifiedGreenLight = Color(0xFFD1FAE5);

  static const Color amberPoll = Color(0xFFFFB020);

  static const Color amberPollLight = Color(0xFFFFFBEB);

  static const Color errorRed = Color(0xFFEF4444);

  static const Color errorRedLight = Color(0xFFFEE2E2);

  static const Color infoBlue = Color(0xFF3B82F6);

  static const Color infoBlueLight = Color(0xFFDBEAFE);

  static const Color womenOnlyPink = Color(0xFFEC4899);

  static const Color womenOnlyPinkLight = Color(0xFFFCE7F3);

  // ─── Shadows ───

  static const Color shadowLight = Color(0x0A000000); // 4% opacity

  static const Color shadowMedium = Color(0x14000000); // 8% opacity

  static const Color shadowHeavy = Color(0x29000000); // 16% opacity

  static const Color tealGlow = Color(0x3300D294);

  // ─── Gradients ───

  static const LinearGradient tealGradient = LinearGradient(
    colors: [
      Color(0xFF00D294),
      Color(0xFF00BFA5),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient navyGradient = LinearGradient(
    colors: [
      Color(0xFF0A1128),
      Color(0xFF172554),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient votingGradient = LinearGradient(
    colors: [
      Color(0xFFFFFBEB),
      Color(0xFFFEF3C7),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ecoGradient = LinearGradient(
    colors: [
      Color(0xFF059669),
      Color(0xFF10B981),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}