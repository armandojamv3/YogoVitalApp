import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
                _buildTextField('Nombre completo', desiredWidth),
                const SizedBox(height: 20),

                // Campo Correo / Teléfono
                _buildTextField('Correo / Telefono', desiredWidth),
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
                ),

                const SizedBox(height: 40),

                // Botón Crear cuenta
                SizedBox(
                  width:
                      MediaQuery.of(context).size.width *
                      0.4, // Ancho 40% del ancho de la pantalla
                  child: ElevatedButton(
                    onPressed: () {
                      print('Creando cuenta...');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
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

  Widget _buildTextField(String hint, double width) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
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
    double width,
  ) {
    return Container(
      width: width, // 3. Usar el ancho pasado
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextField(
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
