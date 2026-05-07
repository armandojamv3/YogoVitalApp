import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';
import 'package:yogo_vital_app/data/datasources/auth_remote_datasource.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/pages/home/home_page.dart';
import 'presentation/pages/splash/welcome_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/register/register_page.dart';

void main() {
  // Construir dependencias mínimas aquí para inyección via Provider
  final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
  final authRemote = AuthRemoteDataSource(apiClient: apiClient);
  final authRepository = AuthRepository(remote: authRemote);

  runApp(MyApp(authRepository: authRepository));
}

class MyApp extends StatelessWidget {
  final AuthRepository? authRepository;
  const MyApp({super.key, this.authRepository});

  @override
  Widget build(BuildContext context) {
    final repo =
        authRepository ??
        AuthRepository(
          remote: AuthRemoteDataSource(
            apiClient: ApiClient(baseUrl: 'http://localhost:8080'),
          ),
        );
    return Provider<AuthRepository>.value(
      value: repo,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Yogo Vital App',
        initialRoute: '/',
        routes: {
          '/': (_) => const WelcomePage(),
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/home': (_) => const HomePage(),
        },
      ),
    );
  }
}
