import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFFF8F9FC);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF1A56DB);
  static const accent = Color(0xFF0E9F6E);
  static const danger = Color(0xFFE02424);
  static const warn = Color(0xFFF59E0B);
  static const safe = Color(0xFF0E9F6E);
  static const moderate = Color(0xFFF59E0B);
  static const critical = Color(0xFFDC2626);
  static const muted = Color(0xFF6B7280);
  static const dark = Color(0xFF111928);
  static const border = Color(0xFFF3F4F6);
  static const redLight = Color(0xFFFEF2F2);
  static const yellowLight = Color(0xFFFFFBEB);
  static const greenLight = Color(0xFFECFDF5);
  static const blueLight = Color(0xFFEFF6FF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
      ),
      textTheme: GoogleFonts.dmSansTextTheme().copyWith(
        headlineLarge: GoogleFonts.dmSans(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
        headlineMedium: GoogleFonts.dmSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
        titleLarge: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.dark,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          color: AppColors.dark,
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 12,
          color: AppColors.muted,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.dark),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.dark,
        ),
      ),
    );
  }

  // Risk level colors
  static Color riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical': return AppColors.critical;
      case 'moderate': return AppColors.moderate;
      default: return AppColors.safe;
    }
  }

  static Color riskBgColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical': return AppColors.redLight;
      case 'moderate': return AppColors.yellowLight;
      default: return AppColors.greenLight;
    }
  }

  static String riskEmoji(String risk) {
    switch (risk.toLowerCase()) {
      case 'critical': return '🔴';
      case 'moderate': return '🟡';
      default: return '🟢';
    }
  }
}
