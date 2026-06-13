import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';

/// Campo de texto reutilizable para las pantallas de autenticación.
///
/// Características:
/// - Relleno blanco, borde píldora (r=28)
/// - Borde azul 2px al enfocar, rojo 2px si [errorText] != null
/// - Mensaje de error: texto blanco sobre fondo rojo translúcido
/// - Compatible con prefixIcon, suffixIcon y obscureText
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  /// Texto de error que se muestra debajo del campo.
  /// Si es null, no hay estado de error.
  final String? errorText;

  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final FocusNode? focusNode;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
    this.errorText,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.enabled = true,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          focusNode: focusNode,
          enabled: enabled,
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: AppColors.inputText,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: AppColors.inputHint,
              fontSize: 15,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: const IconThemeData(
                        color: AppColors.inputIcon, size: 22),
                    child: prefixIcon!,
                  )
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.inputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            // Sin borde en estado normal
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: hasError
                  ? const BorderSide(color: AppColors.error, width: 2)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : AppColors.primary,
                width: 2,
              ),
            ),
          ),
        ),

        // Mensaje de error con fondo rojo translúcido y texto blanco
        if (hasError) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
