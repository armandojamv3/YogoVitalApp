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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', height: 100),
                  const SizedBox(height: 30),
                  const Text(
                    'Registro',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    'Nombre completo',
                    desiredWidth,
                    controller: _nameController,
                    validator: _requiredValidator('Ingresa tu nombre'),
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Correo electrónico',
                    desiredWidth,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    'Teléfono',
                    desiredWidth,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: _requiredValidator('Ingresa tu teléfono'),
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    'Contraseña',
                    _obscurePassword,
                    () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    desiredWidth,
                    controller: _passwordController,
                    validator: _passwordValidator,
                    onChanged: (_) => setState(() {}),
                    helperText:
                        _passwordController.text.isNotEmpty &&
                            _passwordController.text.length < 8
                        ? 'La contraseña debe tener al menos 8 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    'Confirmar contraseña',
                    _obscureConfirmPassword,
                    () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                    desiredWidth,
                    controller: _confirmController,
                    validator: _confirmValidator,
                    onChanged: (_) => setState(() {}),
                    helperText:
                        _confirmController.text.isNotEmpty &&
                            _confirmController.text != _passwordController.text
                        ? 'Las contraseñas no coinciden'
                        : null,
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.4,
                    child: ElevatedButton(
                      onPressed: _loading
                          ? null
                          : () async {
                              final form = _formKey.currentState;
                              if (form == null || !form.validate()) {
                                return;
                              }

                              final repo = Provider.of<AuthRepository>(
                                context,
                                listen: false,
                              );
                              final name = _nameController.text.trim();
                              final email = _emailController.text.trim();
                              final phone = _phoneController.text.trim();
                              final password = _passwordController.text;

                              setState(() => _loading = true);
                              try {
                                final res = await repo.register(
                                  name,
                                  email,
                                  phone,
                                  password,
                                );
                                final token =
                                    res['verification_token'] as String?;
                                if (!context.mounted) return;
                                await showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Registro exitoso'),
                                    content: Text(
                                      token != null
                                          ? 'Hemos enviado un correo a $email. Revisa tu bandeja (o usa este token en modo DEV): $token'
                                          : 'Hemos enviado un correo a $email. Por favor confirma para completar tu registro.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                                if (!context.mounted) return;
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              } catch (e) {
                                if (!context.mounted) return;
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
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Error'),
                                    content: Text(msg),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _loading = false);
                                }
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
      ),
    );
  }

  // --- Widgets Auxiliares Modificados ---

  Widget _buildTextField(
    String hint,
    double width, {
    TextEditingController? controller,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
    String? helperText,
  }) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        onChanged: onChanged,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          helperText: helperText,
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

  String? Function(String?) _requiredValidator(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  String? _emailValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return 'Ingresa tu correo';
    }
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(text)) {
      return 'Ingresa un correo válido';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Ingresa una contraseña';
    }
    if (text.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  String? _confirmValidator(String? value) {
    final text = value ?? '';
    if (text.isEmpty) {
      return 'Confirma tu contraseña';
    }
    if (text != _passwordController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }
}
