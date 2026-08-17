import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/auth_text_field.dart';
import 'package:yogo_vital_app/presentation/widgets/auth/primary_button.dart';
import 'package:yogo_vital_app/presentation/widgets/google_sign_in_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;

  // HU_03: botón activo solo cuando ambos campos tienen contenido y no hay request en curso
  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty &&
      !_loading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email)) {
      _showError('Formato de correo electrónico inválido');
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = context.read<AuthRepository>();
      await repo.login(email, password);
      if (!mounted) return;
      // HU_03: navegar a home en caso de éxito
      Navigator.pushReplacementNamed(context, '/home');
    } on AuthException catch (e) {
      debugPrint('LOGIN AuthException: message="${e.message}" statusCode=${e.statusCode}');
      if (!mounted) return;
      // HU_04: mensaje genérico — no revelar qué campo falló
      _showError('Correo o contraseña incorrectos');
    } catch (e) {
      debugPrint('LOGIN Error: $e');
      if (!mounted) return;
      _showError('Error de conexión. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Inicio de sesión con Google.
  ///
  /// No navega a /home al terminar: el flujo abre el navegador y vuelve por
  /// deep link, así que quien decide qué hacer es el listener de
  /// onAuthStateChange, no esta pantalla. Aquí solo se apaga el indicador si
  /// el usuario cancela y regresa sin haber entrado.
  Future<void> _loginConGoogle() async {
    setState(() => _googleLoading = true);
    try {
      await context.read<AuthRepository>().signInWithGoogle();
    } catch (e) {
      debugPrint('LOGIN Google: $e');
      if (!mounted) return;
      _showError('No se pudo iniciar sesión con Google. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // HU_04: SnackBar rojo flotante con mensaje de error
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Evita que el teclado desplace el fondo
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
            // 24px lateral constante → campos al ~88–90% del ancho
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              // stretch: los widgets heredan el ancho del Column (sin fixed width)
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──────────────────────────────────────────────────
                Align(
                  alignment: Alignment.center,
                  child: Image.asset('assets/images/logo.png', height: 140),
                ),
                const SizedBox(height: 28),

                // ── Título ────────────────────────────────────────────────
                Text(
                  'Inicio de Sesión',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 36),

                // ── Campo: correo ─────────────────────────────────────────
                AuthTextField(
                  controller: _emailController,
                  hintText: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  // Rebuild para activar/desactivar el botón conforme el usuario escribe
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),

                // ── Campo: contraseña ─────────────────────────────────────
                AuthTextField(
                  controller: _passwordController,
                  hintText: 'Contraseña',
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
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
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 32),

                // ── Botón primario ────────────────────────────────────────
                PrimaryButton(
                  label: 'Iniciar sesión',
                  onPressed: _canSubmit ? _login : null,
                  isLoading: _loading,
                ),
                const SizedBox(height: 20),

                // ── Separador ─────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Colors.white38, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Colors.white38, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Continuar con Google ──────────────────────────────────
                // Antes solo estaba en la pantalla de bienvenida, así que
                // quien entraba por "Iniciar sesión" tenía que retroceder
                // para encontrarlo.
                GoogleSignInButton(
                  onPressed: _googleLoading ? null : _loginConGoogle,
                  cargando: _googleLoading,
                ),
                const SizedBox(height: 24),

                // ── Link: recuperar contraseña ────────────────────────────
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/recover'),
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // ── Link: registrarse ─────────────────────────────────────
                // Wrap y no Row: en pantallas estrechas los dos textos
                // juntos no caben y se recortaba "Regístrate aquí". Así, si
                // no cabe en una línea, pasa a la siguiente.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/register'),
                      child: Text(
                        'Regístrate aquí',
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
