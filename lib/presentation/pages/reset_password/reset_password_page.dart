import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles the "new password" step after the user follows the reset-link email.
/// Supabase sets a temporary session via the deep link; this page calls
/// supabase.auth.updateUser() to apply the new password.
class ResetPasswordPage extends StatefulWidget {
  // initialToken kept in constructor for backwards-compat with route registration
  final String? initialToken;
  const ResetPasswordPage({super.key, this.initialToken});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _passwordController.text;
    final pwc = _confirmController.text;

    if (pw.isEmpty || pwc.isEmpty) {
      _snack('Completa todos los campos');
      return;
    }
    if (pw.length < 8) {
      _snack('La contraseña debe tener al menos 8 caracteres');
      return;
    }
    if (pw != pwc) {
      _snack('Las contraseñas no coinciden');
      return;
    }

    setState(() => _loading = true);
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: pw));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Contraseña actualizada'),
          content: const Text(
              'Tu contraseña se actualizó correctamente. Inicia sesión.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (r) => false);
              },
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } catch (_) {
      if (!mounted) return;
      _snack('Error al actualizar la contraseña. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.4;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5B9EF5), Color(0xFF4A8FE7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/logo.png', height: 110),
                  const SizedBox(height: 32),
                  const Text(
                    'Nueva contraseña',
                    style: TextStyle(
                        fontSize: 26,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ingresa y confirma tu nueva contraseña.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Nueva contraseña
                  _buildPasswordField(
                    width, 'Nueva contraseña',
                    _passwordController, _obscure1,
                    () => setState(() => _obscure1 = !_obscure1),
                  ),
                  const SizedBox(height: 16),

                  // Confirmar contraseña
                  _buildPasswordField(
                    width, 'Confirmar contraseña',
                    _confirmController, _obscure2,
                    () => setState(() => _obscure2 = !_obscure2),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: width,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Confirmar',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    double width,
    String hint,
    TextEditingController ctrl,
    bool obscure,
    VoidCallback onToggle,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: onToggle,
          ),
        ),
      ),
    );
  }
}
