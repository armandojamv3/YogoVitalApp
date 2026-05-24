import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // If .env is missing, we fall back to --dart-define below.
  }

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true
      ? dotenv.env['SUPABASE_URL']!.trim()
      : _supabaseUrl;
  final supabaseAnonKey =
      dotenv.env['SUPABASE_ANON_KEY']?.trim().isNotEmpty == true
      ? dotenv.env['SUPABASE_ANON_KEY']!.trim()
      : _supabaseAnonKey;

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Faltan SUPABASE_URL o SUPABASE_ANON_KEY. Crea un archivo .env o usa --dart-define.',
    );
  }

  // Cliente de Supabase para el frontend: aquí se inicializa la conexión
  // de la app Flutter con el proyecto de Supabase usando la anon key.
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  // La app no habla directo con la BD desde aquí: usa un backend HTTP local.
  // Ese backend es el que luego se conecta a la base de datos de Supabase.
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
