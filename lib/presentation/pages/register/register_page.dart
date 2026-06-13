import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/auth_text_field.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/primary_button.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // ── Visibilidad contraseñas ───────────────────────────────────────────────
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // ── Controladores ─────────────────────────────────────────────────────────
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading = false;

  // HU_02: validación de email en tiempo real
  String? _emailError;
  bool _checkingEmail = false;
  Timer? _emailDebounce;

  static final _emailRegExp = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── HU_02: validación formato + duplicado con debounce ───────────────────

  void _onEmailChanged(String val) {
    _emailDebounce?.cancel();
    final email = val.trim();

    if (email.isEmpty) {
      setState(() => _emailError = null);
      return;
    }

    if (!_emailRegExp.hasMatch(email)) {
      setState(() => _emailError = 'Formato de correo inválido');
      return;
    }

    // Formato OK — limpiar error y verificar duplicado tras 800 ms
    setState(() => _emailError = null);

    _emailDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (!mounted) return;
      setState(() => _checkingEmail = true);
      try {
        final exists =
            await context.read<AuthRepository>().isEmailRegistered(email);
        if (!mounted) return;
        setState(() {
          _checkingEmail = false;
          _emailError = exists ? 'Correo ya registrado' : null;
        });
      } catch (_) {
        if (mounted) setState(() => _checkingEmail = false);
      }
    });
  }

  // ── Registro ──────────────────────────────────────────────────────────────

  Future<void> _register() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    // HU_01: todos los campos obligatorios
    if (name.isEmpty || email.isEmpty || phone.isEmpty ||
        password.isEmpty || confirm.isEmpty) {
      _showSnack('Por favor, completa todos los campos');
      return;
    }
    if (_emailError != null) {
      _showSnack('Corrige el correo electrónico antes de continuar');
      return;
    }
    if (!_emailRegExp.hasMatch(email)) {
      _showSnack('Formato de correo electrónico inválido');
      return;
    }
    // HU_01: mínimo 8 caracteres
    if (password.length < 8) {
      _showSnack('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    // HU_01: contraseñas coincidentes
    if (password != confirm) {
      _showSnack('Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    try {
      await context.read<AuthRepository>().register(
        name: name,
        email: email,
        phone: phone,
        password: password,
      );
      if (!mounted) return;
      FocusScope.of(context).unfocus();

      // HU_01: diálogo de confirmación
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('¡Registro exitoso!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'Hemos enviado un correo de confirmación a $email.\n'
            'Confirma tu cuenta para poder iniciar sesión.',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Entendido',
                  style: GoogleFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } on AuthException catch (e) {
      debugPrint('REGISTER AuthException: message="${e.message}" statusCode=${e.statusCode}');
      if (!mounted) return;
      _showSnack(_parseAuthError(e.message));
    } catch (e) {
      debugPrint('REGISTER Error: $e');
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('429') || msg.contains('rate')) {
        _showSnack('Demasiados intentos. Espera unos minutos e inténtalo de nuevo.');
      } else {
        _showSnack('Error de conexión. Intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _parseAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('already exists') ||
        lower.contains('user already')) {
      return 'Correo ya registrado';
    }
    if (lower.contains('password')) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return 'Error al registrar. Intenta de nuevo.';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
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

  // ── Build ─────────────────────────────────────────────────────────────────

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
                // ── Logo ────────────────────────────────────────────────
                Align(
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/logo.png', height: 90),
                ),
                const SizedBox(height: 20),

                // ── Título ───────────────────────────────────────────────
                Text(
                  'Crear Cuenta',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Nombre completo ──────────────────────────────────────
                AuthTextField(
                  controller: _nameCtrl,
                  hintText: 'Nombre completo',
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outline),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-ZáéíóúÁÉÍÓÚñÑ\s']")),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Email con validación en tiempo real ──────────────────
                AuthTextField(
                  controller: _emailCtrl,
                  hintText: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  // Spinner mientras verifica duplicado
                  suffixIcon: _checkingEmail
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.inputIcon,
                            ),
                          ),
                        )
                      : null,
                  errorText: _emailError,
                  onChanged: _onEmailChanged,
                ),
                const SizedBox(height: 16),

                // ── Teléfono ─────────────────────────────────────────────
                AuthTextField(
                  controller: _phoneCtrl,
                  hintText: 'Teléfono',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.phone_outlined),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 16),

                // ── Contraseña ───────────────────────────────────────────
                AuthTextField(
                  controller: _passwordCtrl,
                  hintText: 'Contraseña',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.inputIcon,
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Confirmar contraseña ─────────────────────────────────
                AuthTextField(
                  controller: _confirmCtrl,
                  hintText: 'Confirmar contraseña',
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.inputIcon,
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Botón primario ───────────────────────────────────────
                PrimaryButton(
                  label: 'Crear cuenta',
                  onPressed: _loading ? null : _register,
                  isLoading: _loading,
                ),
                const SizedBox(height: 24),

                // ── Link: ir al login ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Ya tienes cuenta? ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/login'),
                      child: Text(
                        'Inicia sesión',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
