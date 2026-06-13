import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/auth_text_field.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/primary_button.dart';

class RecoverPasswordPage extends StatefulWidget {
  const RecoverPasswordPage({super.key});

  @override
  State<RecoverPasswordPage> createState() => _RecoverPasswordPageState();
}

class _RecoverPasswordPageState extends State<RecoverPasswordPage> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  static final _emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  bool get _canSubmit =>
      _emailCtrl.text.trim().isNotEmpty && !_loading;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      _showError('Ingresa tu correo electrónico');
      return;
    }
    if (!_emailRegExp.hasMatch(email)) {
      _showError('Formato de correo inválido');
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthRepository>().resetPassword(email);
    } on AuthException {
      // Caída silenciosa intencional
    } catch (_) {
      // Caída silenciosa intencional
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        // HU_05: siempre mostrar el mismo mensaje por seguridad
        // (no revelar si la cuenta existe o no)
        _showSuccess();
      }
    }
  }

  // HU_05: diálogo de éxito genérico
  void _showSuccess() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Correo enviado',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Hemos enviado un enlace de recuperación a tu correo.\n'
          'El enlace expirará automáticamente por seguridad.',
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // volver al login
            },
            child: Text(
              'Aceptar',
              style: GoogleFonts.poppins(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Botón volver ────────────────────────────────────────
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Logo ────────────────────────────────────────────────
                Align(
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/logo.png', height: 110),
                ),
                const SizedBox(height: 28),

                // ── Título ───────────────────────────────────────────────
                Text(
                  'Recuperar\nContraseña',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Subtítulo ────────────────────────────────────────────
                Text(
                  'Ingresa tu correo y te enviaremos\nun enlace para restablecer tu contraseña.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Campo: correo ────────────────────────────────────────
                AuthTextField(
                  controller: _emailCtrl,
                  hintText: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.email_outlined),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 32),

                // ── Botón enviar ─────────────────────────────────────────
                PrimaryButton(
                  label: 'Enviar enlace',
                  onPressed: _canSubmit ? _sendReset : null,
                  isLoading: _loading,
                ),
                const SizedBox(height: 24),

                // ── Link: volver al login ────────────────────────────────
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 16),
                  label: Text(
                    'Volver al inicio de sesión',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    alignment: Alignment.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
