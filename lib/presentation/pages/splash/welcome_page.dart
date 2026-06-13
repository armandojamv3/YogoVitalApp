import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _googleLoading = false;
  bool _waitingForOAuth = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_waitingForOAuth &&
          data.event == AuthChangeEvent.signedIn &&
          mounted) {
        _waitingForOAuth = false;
        await _handleSignedIn(data.session?.user);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleSignedIn(User? user) async {
    if (user == null) return;
    try {
      await context.read<AuthRepository>().ensureUsuarioExists(user);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _waitingForOAuth = true;
    });
    try {
      await context.read<AuthRepository>().signInWithGoogle();
    } catch (_) {
      _waitingForOAuth = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo iniciar sesión con Google. Intenta de nuevo.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ──────────────────────────────────────────────────
                Center(
                  child: Image.asset('assets/images/logo.png', height: 120),
                ),
                const SizedBox(height: 36),

                // ── Título ────────────────────────────────────────────────
                Text(
                  'Bienvenido\na Yogo Vital',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 14),

                // ── Subtítulo ─────────────────────────────────────────────
                Text(
                  'Personaliza tu yogur\ncomo más te guste',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 56),

                // ── Botón: Iniciar sesión ─────────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDeep,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      'Iniciar sesión',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Botón: Registrarse ────────────────────────────────────
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      'Registrarse',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Divisor "o" ───────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(
                      child: Divider(color: Colors.white38, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'o',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(color: Colors.white38, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Botón: Continuar con Google ───────────────────────────
                SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _googleLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      side: const BorderSide(
                          color: Color(0xFFDADADA), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _googleLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _GoogleG(),
                              const SizedBox(width: 10),
                              Text(
                                'Continuar con Google',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" logo rendered via CustomPainter with the 4 brand colors.
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGPainter()),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;
    final strokeW = size.width * 0.18;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.butt;

    // Blue  — top (315° → 45° going clockwise, i.e. from -45° span 90°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        -1.5708 - 0.7854, 1.5708, false, paint); // top-right quadrant

    // Red — right (45° → 135°)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        -0.7854, 1.5708, false, paint);

    // Yellow — bottom (135° → 225°)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        0.7854, 1.5708, false, paint);

    // Green — left (225° → 315°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r - strokeW / 2),
        2.3562, 1.5708, false, paint);

    // White inner fill + cutout to create the "C" opening on the right
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r - strokeW, fillPaint);

    // Horizontal bar of the G
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final barTop = cy - strokeW * 0.45;
    final barBottom = cy + strokeW * 0.45;
    canvas.drawRect(
      Rect.fromLTRB(cx, barTop, cx + r - strokeW * 0.3, barBottom),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
