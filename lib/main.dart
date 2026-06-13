import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';
import 'package:yogo_vital_app/core/providers/auth_provider.dart';
import 'package:yogo_vital_app/core/providers/pedido_provider.dart';
import 'package:yogo_vital_app/data/datasources/auth_remote_datasource.dart';
import 'package:yogo_vital_app/data/repositories/auth_repository.dart';
import 'package:yogo_vital_app/presentation/pages/home/home_page.dart';
import 'package:yogo_vital_app/presentation/pages/home/product_detail_page.dart';
import 'package:yogo_vital_app/presentation/pages/yogurt/yogurt_page.dart';
import 'package:yogo_vital_app/presentation/pages/cart/cart_page.dart';
import 'package:yogo_vital_app/presentation/pages/history/history_page.dart';
import 'package:yogo_vital_app/presentation/pages/account/account_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_orders_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_sabores_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_frutas_extras_page.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_dashboard_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/pedido_admin_detalle_screen.dart';
import 'package:yogo_vital_app/presentation/pages/orders/estado_pedido_page.dart';
import 'package:yogo_vital_app/presentation/pages/orders/estado_pedido_supabase_page.dart';
import 'package:yogo_vital_app/presentation/pages/orders/resumen_pedido_page.dart';
import 'package:yogo_vital_app/presentation/pages/orders/direcciones_page.dart';
import 'package:yogo_vital_app/presentation/pages/orders/factura_screen.dart';
import 'package:yogo_vital_app/presentation/pages/orders/calificacion_screen.dart';
import 'package:yogo_vital_app/presentation/pages/account/perfil_screen.dart';
import 'presentation/pages/splash/welcome_page.dart';
import 'presentation/pages/login/login_page.dart';
import 'presentation/pages/register/register_page.dart';
import 'presentation/pages/recover_password/recover_password_page.dart';
import 'presentation/pages/reset_password/reset_password_page.dart';

const _supabaseUrl = 'https://ovoinhzefxdixpmnzwcr.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im92b2luaHplZnhkaXhwbW56d2NyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyNDQ2ODIsImV4cCI6MjA5NTgyMDY4Mn0.5oR6-ghoe8xGai_qO4RTKXEIr3fOrv7r5iRs8b62q5c';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  final authRemote = AuthRemoteDataSource();
  final authRepo = AuthRepository(remote: authRemote);
  final apiClient = ApiClient(baseUrl: 'http://10.0.2.2:8080');

  runApp(MyApp(authRepository: authRepo, apiClient: apiClient));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ApiClient apiClient;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.apiClient,
  });

  @override
  Widget build(BuildContext context) {
    final hasSession =
        Supabase.instance.client.auth.currentSession != null;

    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)),
        ChangeNotifierProvider(create: (_) => CartModel()),
        // Sprint 3+4: PedidoProvider elevado a nivel app para que
        // ResumenPedidoPage acceda al pedido en construcción
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Yogo Vital App',
        theme: AppTheme.light,
        initialRoute: hasSession ? '/home' : '/',
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
          '/admin': (_) => const AdminOrdersPage(),
          // Sprint 4: resumen + dirección + confirmación
          '/resumen-pedido': (_) => const ResumenPedidoPage(),
          '/mis-direcciones': (_) => const DireccionesPage(),
          // Sprint 4: seguimiento con Supabase Realtime
          '/estado-pedido': (ctx) {
            final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
            return EstadoPedidoSupabasePage(pedidoId: id);
          },
          // Ruta legacy (Dart Frog) — mantenida por compatibilidad
          '/estado-pedido-legacy': (ctx) {
            final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
            return EstadoPedidoPage(pedidoId: id);
          },
          '/admin/sabores': (_) => const AdminSaboresPage(),
          '/admin/frutas-extras': (_) => const AdminFrutasExtrasPage(),
          '/admin/dashboard': (_) => const AdminDashboardPage(),
          '/admin/pedido-detalle': (ctx) {
            final id =
                ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
            return PedidoAdminDetalleScreen(pedidoId: id);
          },
          // Sprint 5
          '/perfil': (_) => const PerfilScreen(),
          '/factura': (ctx) {
            final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
            return FacturaScreen(pedidoId: id);
          },
          '/calificacion': (ctx) {
            final id = ModalRoute.of(ctx)!.settings.arguments as String? ?? '';
            return CalificacionScreen(pedidoId: id);
          },
        },
      ),
    );
  }
}
