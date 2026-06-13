import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';

/// Botón primario para pantallas de autenticación.
///
/// - Fondo blanco (contrasta con el fondo azul)
/// - Texto azul oscuro [AppColors.primaryDeep]
/// - [onPressed] null → estado deshabilitado (blanco 50% opacidad)
/// - [isLoading] true → muestra CircularProgressIndicator en lugar del label
class PrimaryButton extends StatelessWidget {
  final String label;

  /// Si es null, el botón queda deshabilitado visualmente.
  final VoidCallback? onPressed;

  final bool isLoading;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryDeep,
                  ),
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? AppColors.primaryDeep
                      : AppColors.primaryDeep.withValues(alpha: 0.5),
                ),
              ),
      ),
    );
  }
}
