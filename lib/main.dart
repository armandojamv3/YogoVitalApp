import 'package:flutter/material.dart';
import 'package:yogo_vital_app/presentation/pages/home/home_page.dart';
import 'presentation/pages/splash/welcome_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/register/register_page.dart';

void main() {
  runApp(const MyApp());
}

// StatefulWidget es un widget que No cambia de estado
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
  }); // Crea una instancia de MyApp,Constructor (forma de crear el objeto)

  @override // Sobrescribe el método build de StatelessWidget
  Widget build(BuildContext context) {
    // Construye y devuelve un widget
    return MaterialApp(
      //Devuelve MaterialApp (el contenedor principal)
      debugShowCheckedModeBanner: false,
      title: 'Yogo Vital App',
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomePage(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
      },
    );
  }
}
