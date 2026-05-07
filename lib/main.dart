import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';
import 'package:yogo_vital_app/data/datasources/auth_remote_datasource.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/pages/home/home_page.dart';
import 'package:yogo_vital_app/presentation/pages/home/product_detail_page.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/yogurt_page.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_page.dart';
import 'package:yogo_vital_app/presentation/pages/history/history_page.dart';
import 'package:yogo_vital_app/presentation/pages/account/account_page.dart';
import 'presentation/pages/splash/welcome_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/register/register_page.dart';
import 'presentation/pages/recover_password/recover_password_page.dart';
import 'presentation/pages/reset_password/reset_password_page.dart';

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
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: repo),
        ChangeNotifierProvider(create: (_) => CartModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Yogo Vital App',
        initialRoute: '/',
        routes: {
          '/': (_) => const WelcomePage(),
          '/login': (_) => const LoginPage(),
          '/register': (_) => const RegisterPage(),
          '/recover': (_) => const RecoverPasswordPage(),
          '/reset-password': (_) => ResetPasswordPage(
            initialToken: Uri.base.queryParameters['token'],
          ),
          '/home': (_) => const HomePage(),
          '/yogurt': (_) => const YogurtPage(),
          '/cart': (_) => const CartPage(),
          '/detail': (_) => const ProductDetailPage(),
          '/history': (_) => const HistoryPage(),
          '/account': (_) => const AccountPage(),
        },
      ),
    );
  }
}
