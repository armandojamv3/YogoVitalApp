import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta de colores centralizada del proyecto.
abstract class AppColors {
  // Fondo auth (se mantiene igual al original)
  static const gradientTop = Color(0xFF5B9EF5);
  static const gradientBottom = Color(0xFF4A8FE7);

  // Primarios
  static const primary = Color(0xFF5B9EF5);
  static const primaryDark = Color(0xFF4A8FE7);
  static const primaryDeep = Color(0xFF1B3A7A); // botón sobre fondo azul

  // Semánticos
  static const error = Color(0xFFE24B4A);
  static const success = Color(0xFF4CAF50);

  // Inputs
  static const inputFill = Colors.white;
  static const inputHint = Color(0xFF9E9E9E);   // grey.shade500
  static const inputIcon = Color(0xFF9E9E9E);
  static const inputText = Color(0xFF1A1A2E);

  // Superficie
  static const white = Colors.white;
  static const background = Color(0xFFF5F7FA);
}

/// ThemeData global — aplica Poppins + estilos de inputs/botones.
abstract class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: false);
    final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        error: AppColors.error,
      ),

      // ── Inputs ───────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.poppins(
          color: AppColors.inputHint,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        prefixIconColor: AppColors.inputIcon,
        suffixIconColor: AppColors.inputIcon,
      ),

      // ── Botón elevado global ──────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.primaryDeep,
          disabledBackgroundColor: AppColors.white.withValues(alpha: 0.5),
          disabledForegroundColor:
              AppColors.primaryDeep.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
