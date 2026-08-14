import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/cart_model.dart';
import 'package:yogo_vital_app/core/providers/auth_provider.dart';
import 'package:yogo_vital_app/core/providers/pedido_provider.dart';
import 'package:yogo_vital_app/core/services/push_service.dart';
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
import 'package:yogo_vital_app/presentation/pages/admin/admin_promociones_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_predisenhados_page.dart';
import 'package:yogo_vital_app/core/theme/app_theme.dart';
import 'package:yogo_vital_app/presentation/pages/admin/admin_dashboard_page.dart';
import 'package:yogo_vital_app/presentation/pages/admin/pedido_admin_detalle_screen.dart';
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

/// Navegador global.
///
/// Hace falta para poder navegar desde fuera del árbol de widgets: cuando el
/// usuario abre el enlace de "recuperar contraseña", el evento de Supabase
/// llega a un listener que no tiene BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  // No se espera con await a propósito: si Firebase tarda o falla, la app
  // debe arrancar igual. Sin push se pierden los avisos con la app cerrada,
  // pero las notificaciones in-app se siguen guardando en Supabase.
  PushService.instance.iniciar();

  _escucharRecuperacionDePassword();
  _atarPushAlCicloDeSesion();

  final authRemote = AuthRemoteDataSource();
  final authRepo = AuthRepository(remote: authRemote);

  runApp(MyApp(authRepository: authRepo));
}

/// Registra el dispositivo para recibir push al iniciar sesión.
///
/// La baja NO se hace aquí. Cuando llega el evento `signedOut`, la sesión ya
/// está cerrada y `auth.uid()` es null, así que la RPC que borra el token no
/// tendría a quién atribuirlo. Se hace antes, dentro de
/// AuthRepository.logout().
void _atarPushAlCicloDeSesion() {
  final auth = Supabase.instance.client.auth;

  // Sesión ya activa al abrir la app: no dispara signedIn.
  if (auth.currentUser != null) {
    PushService.instance.registrarParaUsuarioActual();
  }

  auth.onAuthStateChange.listen((estado) {
    if (estado.event == AuthChangeEvent.signedIn) {
      PushService.instance.registrarParaUsuarioActual();
    }
  });
}

/// Lleva al usuario a poner su nueva contraseña cuando abre el enlace del
/// correo de recuperación.
///
/// Supabase abre la app por deep link, canjea el token y emite
/// `passwordRecovery` con una sesión temporal ya activa. Sin este listener la
/// app se quedaba en la pantalla de bienvenida: el enlace "funcionaba" pero
/// no llevaba a ningún sitio, y ResetPasswordPage solo era alcanzable
/// escribiendo la ruta a mano.
void _escucharRecuperacionDePassword() {
  Supabase.instance.client.auth.onAuthStateChange.listen((estado) {
    if (estado.event != AuthChangeEvent.passwordRecovery) return;
    // Se limpia la pila: el usuario viene de un correo, no de navegar por
    // la app, así que no tiene sentido dejarle un "atrás".
    navigatorKey.currentState
        ?.pushNamedAndRemoveUntil('/reset-password', (r) => false);
  });
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;

  const MyApp({
    super.key,
    required this.authRepository,
  });

  /// Ata el carrito al ciclo de sesión.
  ///
  /// El carrito se respalda en SQLite por `cliente_id` (ver CartModel), así
  /// que hay que decirle cuándo cargar el de quien entra y cuándo borrarlo.
  /// Sin esto el carrito volvería a perderse en cada arranque, y el de una
  /// cuenta le aparecería a la siguiente que use el dispositivo.
  CartModel _crearCarrito() {
    final cart = CartModel();
    final auth = Supabase.instance.client.auth;

    // Sesión ya activa al abrir la app (no dispara signedIn).
    final actual = auth.currentUser?.id;
    if (actual != null) cart.cargarPara(actual);

    auth.onAuthStateChange.listen((estado) {
      final uid = estado.session?.user.id;
      if (uid != null) {
        // cargarPara ignora el caso "mismo cliente", así que los eventos
        // de refresco de token no relanzan la lectura.
        cart.cargarPara(uid);
      } else if (estado.event == AuthChangeEvent.signedOut) {
        cart.limpiarPorCierreDeSesion();
      }
    });

    return cart;
  }

  @override
  Widget build(BuildContext context) {
    final hasSession =
        Supabase.instance.client.auth.currentSession != null;

    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider(create: (_) => AuthProvider(authRepository)),
        ChangeNotifierProvider(create: (_) => _crearCarrito()),
        // Sprint 3+4: PedidoProvider elevado a nivel app para que
        // ResumenPedidoPage acceda al pedido en construcción
        ChangeNotifierProvider(create: (_) => PedidoProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'Yogo Vital App',
        theme: AppTheme.light,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
        locale: const Locale('es'),
        initialRoute: hasSession ? '/home' : '/',
        // El pedidoId de '/estado-pedido' viaja embebido en la URL
        // (/estado-pedido/<id>) en vez de como `arguments`, para que
        // sobreviva a un F5 / recarga del navegador en Flutter Web
        // (los `arguments` de una ruta solo viven en memoria y se pierden
        // al recargar la página).
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '');
          if (uri.pathSegments.length == 2 &&
              uri.pathSegments.first == 'estado-pedido') {
            final id = uri.pathSegments[1];
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => EstadoPedidoSupabasePage(pedidoId: id),
            );
          }
          return null;
        },
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
          '/admin/sabores': (_) => const AdminSaboresPage(),
          '/admin/frutas-extras': (_) => const AdminFrutasExtrasPage(),
          '/admin/promociones': (_) => const AdminPromocionesPage(),
          '/admin/predisenhados': (_) => const AdminPredisenhadosPage(),
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
