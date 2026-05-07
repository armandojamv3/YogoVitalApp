import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Definir el ancho deseado (ej: 80% del ancho de la pantalla)
    final desiredWidth = MediaQuery.of(context).size.width * 0.4;

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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 100),
                const SizedBox(height: 30),

                // Título
                const Text(
                  'Registro',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 40),

                // Campo Nombre completo
                // 2. Pasar el ancho deseado a las funciones de construcción
                _buildTextField(
                  'Nombre completo',
                  desiredWidth,
                  controller: _nameController,
                ),
                const SizedBox(height: 20),

                // Campo Correo / Teléfono
                _buildTextField(
                  'Correo electrónico',
                  desiredWidth,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),

                // Campo Contraseña
                _buildPasswordField(
                  'Contraseña',
                  _obscurePassword,
                  () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  desiredWidth, // 2. Pasar el ancho deseado
                  controller: _passwordController,
                ),
                const SizedBox(height: 20),

                // Campo Confirmar contraseña
                _buildPasswordField(
                  'Confirmar contraseña',
                  _obscureConfirmPassword,
                  () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  desiredWidth, // 2. Pasar el ancho deseado
                  controller: _confirmController,
                ),

                const SizedBox(height: 40),

                // Botón Crear cuenta
                SizedBox(
                  width:
                      MediaQuery.of(context).size.width *
                      0.4, // Ancho 40% del ancho de la pantalla
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            final repo = Provider.of<AuthRepository>(
                              context,
                              listen: false,
                            );
                            final name = _nameController.text.trim();
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;
                            final confirm = _confirmController.text;
                            if (name.isEmpty ||
                                email.isEmpty ||
                                password.isEmpty ||
                                confirm.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Completa todos los campos'),
                                ),
                              );
                              return;
                            }
                            if (password != confirm) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Las contraseñas no coinciden'),
                                ),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              final res = await repo.register(
                                name,
                                email,
                                password,
                              );
                              // Mostrar diálogo indicando que se envió el correo de verificación.
                              final token =
                                  res['verification_token'] as String?;
                              if (!mounted) return;
                              await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Registro iniciado'),
                                  content: Text(
                                    token != null
                                        ? 'Hemos enviado un correo a $email. Revisa tu bandeja (o usa este token en modo DEV): $token'
                                        : 'Hemos enviado un correo a $email. Por favor confirma para completar tu registro.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              if (!mounted) return;
                              Navigator.pushReplacementNamed(context, '/login');
                            } catch (e) {
                              if (!mounted) return;
                              String msg = 'Error al registrar';
                              if (e is ApiException) {
                                msg =
                                    (e.body['message'] ??
                                            e.body['error'] ??
                                            msg)
                                        .toString();
                              } else {
                                msg = e.toString();
                              }
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Error'),
                                  content: Text(msg),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Crear cuenta',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                // Texto "¿Ya tienes cuenta? Inicia sesión"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿Ya tienes cuenta? ',
                      style: TextStyle(color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: const Text(
                        'Inicia sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares Modificados ---

  Widget _buildTextField(
    String hint,
    double width, {
    TextEditingController? controller,
    TextInputType? keyboardType,
  }) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String hint,
    bool obscure,
    VoidCallback onToggle,
    double width, {
    TextEditingController? controller,
  }) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 18,
          ),
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
