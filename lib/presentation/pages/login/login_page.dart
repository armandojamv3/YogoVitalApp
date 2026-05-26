import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

//Esta clase HEREDA de StatefulWidget (puede cambiar)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  //Es como decir: Voy a crear un tipo de widget nuevo
  //llamado LoginPage que puede cambiar con el tiempo

  // dato generico, este metodo  retorna tipo LoginPage la cual se llamara
  //createState y  este va a crear un  _LoginPageState osea se crea una instancia
  // La clase privada (el _ significa privada) que contiene la lógica
  @override
  State<LoginPage> createState() => _LoginPageState();
}

//extends State<LoginPage>` → Maneja el estado de LoginPage
class _LoginPageState extends State<LoginPage> {
  // _obscurePassword` = nombre de la variable (privada por el `_`)
  // `bool` = tipo de dato (booleano: true o false)
  bool _obscurePassword =
      true; // Variable para ocultar/mostrar contraseña,comienza siendo verdadero
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorField; // Tracks which field has an error ('email' or 'password')
  String? _errorMessage; // The error message to display

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Builds a text field with error styling if it's the failed field
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String fieldName,
    required bool isPasswordField,
  }) {
    final isErrorField = _errorField == fieldName;
    final borderColor = isErrorField ? Colors.red : Colors.white;

    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: borderColor,
          width: isErrorField ? 2.0 : 0.0,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: fieldName == 'email'
            ? TextInputType.emailAddress
            : TextInputType.text,
        obscureText: isPasswordField ? _obscurePassword : false,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: label,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 25,
            vertical: 18,
          ),
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
        ),
        onChanged: (_) {
          // Clear error when user starts typing
          if (_errorField == fieldName) {
            setState(() {
              _errorField = null;
              _errorMessage = null;
            });
          }
        },
      ),
    );
  }

  @override
  // build Método que construye la interfaz de usuario
  // BuildContext context  Información sobre dónde está este widget en el árbol
  Widget build(BuildContext context) {
    //Devuelve un Scaffold (estructura base de pantalla)
    return Scaffold(
      body: Container(
        // Contenedor principal,Una caja que contiene otros widgets
        width: double.infinity, //Ancho = 100% de la pantalla
        height: double.infinity, //Alto = 100% de la pantalla
        //decoration: Esta es una propiedad de un widget como Container o DecoratedBox
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF5B9EF5),
              Color(0xFF4A8FE7),
            ], //Define los colores inicial y final del degradado
            begin: Alignment
                .topCenter, // Punto de inicio del degradado (centro superior)
            end: Alignment
                .bottomCenter, // Punto final del degradado (centro inferior)
          ),
        ),
        child: SafeArea(
          //SafeArea evita que el contenido se dibuje debajo de la barra de estado(hora, batería, etc.) y el notch la muesca en algunos dispositivos
          child: SingleChildScrollView(
            //Permite desplazamiento si el contenido es más grande que la pantalla
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            // permite hacer scroll si el  contenido es más grande que la pantalla y padding es el espacio interno y lo otro es el espacio vertical y horizontal
            child: Column(
              //Organiza los widgets en una columna (de arriba hacia abajo)
              crossAxisAlignment: CrossAxisAlignment
                  .center, // centra horizontalmente todos los hijos de la columna
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 150), //
                const SizedBox(height: 30), //Espacio vertical de 30 píxeles
                // Título
                const Text(
                  'Inicio de Sessión',
                  style: TextStyle(
                    fontSize: 28, //Tamaño de la fuente
                    fontWeight: FontWeight.bold, //Negrita
                    color: Colors.white, //Color blanco
                  ),
                ),

                const SizedBox(height: 40), //Espacio vertical de 40 píxeles
                // Campo Correo electrónico
                _buildTextField(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  fieldName: 'email',
                  isPasswordField: false,
                ),

                const SizedBox(height: 20),

                // Campo Contraseña
                _buildTextField(
                  controller: _passwordController,
                  label: 'Contraseña',
                  fieldName: 'password',
                  isPasswordField: true,
                ),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 40), //Espacio vertical de 40 píxeles
                // Botón Iniciar sesión
                SizedBox(
                  // Contenedor para el botón inicio sesion
                  width:
                      MediaQuery.of(context).size.width *
                      0.4, // Ancho = 40% del ancho de la pantalla
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            final repo = Provider.of<AuthRepository>(
                              context,
                              listen: false,
                            );
                            final email = _emailController.text.trim();
                            final password = _passwordController.text;
                            if (email.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ingresa correo y contraseña'),
                                ),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              final res = await repo.login(email, password);
                              // `AuthRepository.login` guarda el token si existe.
                              final token = res['token'] as String?;
                              if (!context.mounted) return;
                              if (token != null && token.isNotEmpty) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/home',
                                );
                              } else {
                                final msg =
                                    (res['message'] ?? 'Error desconocido')
                                        .toString();
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
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              if (e is ApiException) {
                                // Extract field and error message from response
                                final field = 
                                    e.body['field'] as String?;
                                final msg =
                                    (e.body['error'] ??
                                            'Error de autenticación')
                                        .toString();
                                setState(() {
                                  _errorField = field;
                                  _errorMessage = msg;
                                  // Clear password field on auth failure
                                  if (field == 'password') {
                                    _passwordController.clear();
                                  }
                                });
                              } else {
                                showDialog(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Error'),
                                    content: Text(e.toString()),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext),
                                        child: const Text('OK'),
                                      ),
                                    ],
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _loading = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      // Estilo del botón
                      backgroundColor: const Color(0xFF0D47A1),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ), // Espaciado interno vertical de 16 píxeles
                      shape: RoundedRectangleBorder(
                        // Forma del botón
                        borderRadius: BorderRadius.circular(
                          30,
                        ), // Bordes redondeados con radio de 30
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
                            // Texto del botón
                            'Iniciar sesión',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/recover');
                  },
                  child: const Text(
                    '¿Olvidaste tu contraseña?',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),

                const SizedBox(height: 20), //Espacio vertical de 20 píxeles
                // Texto "¿No tienes cuenta? Regístrate aquí"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '¿No tienes cuenta? ',
                      style: TextStyle(color: Colors.white),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Botón Google
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.4, // Ancho = 40% del ancho de la pantalla
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.login, color: Colors.red),
                      SizedBox(width: 10),
                      Text(
                        'Inicio de sessión con Google',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
