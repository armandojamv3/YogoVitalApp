import 'dart:async';

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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Se pinta ANTES de inicializar nada. Ver ArranqueApp.
  runApp(const ArranqueApp());
}

/// Future compartido de la inicialización de Supabase.
///
/// Se guarda fuera del widget para que el botón "Reintentar" vuelva a
/// esperar la MISMA inicialización en vez de lanzar otra. Llamar dos veces a
/// `Supabase.initialize` deja la librería en un estado indefinido.
Future<Supabase>? _futuroSupabase;

/// Pantalla de arranque de la app.
///
/// ── Por qué existe ────────────────────────────────────────────────────
/// Antes `main()` hacía `await Supabase.initialize(...)` **antes** de llamar
/// a `runApp`. Ese await no es trabajo local: supabase_flutter recupera la
/// sesión guardada y, si el token ya caducó, pide uno nuevo por red. Con
/// cobertura mala esa petición tarda lo que tarde el tiempo de espera de
/// HTTP, y mientras tanto la app no ha pintado ni un píxel: el teléfono se
/// queda en la pantalla de arranque del sistema y parece colgada.
///
/// Ahora se pinta primero y se inicializa después, con un límite de tiempo y
/// una salida si falla, en vez de una espera sin final visible.
class ArranqueApp extends StatefulWidget {
  const ArranqueApp({super.key});

  @override
  State<ArranqueApp> createState() => _ArranqueAppState();
}

enum _Fase { cargando, listo, error }

class _ArranqueAppState extends State<ArranqueApp> {
  _Fase _fase = _Fase.cargando;
  String? _error;
  AuthRepository? _authRepo;

  @override
  void initState() {
    super.initState();
    _arrancar();
  }

  Future<void> _arrancar() async {
    setState(() {
      _fase = _Fase.cargando;
      _error = null;
    });

    try {
      await initializeDateFormatting('es', null);

      _futuroSupabase ??= Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      await _futuroSupabase!.timeout(const Duration(seconds: 20));

      // No se espera con await a propósito: si Firebase tarda o falla, la
      // app debe arrancar igual. Sin push se pierden los avisos con la app
      // cerrada, pero las notificaciones in-app se siguen guardando en
      // Supabase.
      PushService.instance.iniciar();

      _escucharRecuperacionDePassword();
      _atarPushAlCicloDeSesion();

      _authRepo = AuthRepository(remote: AuthRemoteDataSource());

      if (!mounted) return;
      setState(() => _fase = _Fase.listo);
    } catch (e) {
      debugPrint('[Arranque] falló la inicialización: $e');
      if (!mounted) return;
      setState(() {
        _fase = _Fase.error;
        _error = e is TimeoutException
            ? 'No se pudo conectar. Revisa tu conexión a internet.'
            : 'No se pudo iniciar la aplicación.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fase == _Fase.listo) {
      return MyApp(authRepository: _authRepo!);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Blanco, igual que la pantalla de arranque de Android (ver
      // res/values/styles.xml). Si aquí se pone otro color, el usuario ve un
      // salto de fondo justo cuando Flutter toma el relevo.
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', width: 140),
                const SizedBox(height: 28),
                if (_fase == _Fase.cargando)
                  const CircularProgressIndicator(color: Color(0xFF5B9EF5))
                else ...[
                  Text(
                    _error ?? 'No se pudo iniciar la aplicación.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFF444444), fontSize: 15),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _arrancar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5B9EF5),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Reintentar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
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
        // Es el nombre que se ve en el selector de apps recientes de
        // Android. Se deja igual que el del icono para que no aparezcan
        // dos nombres distintos para la misma app.
        title: 'Yogo Vital',
        theme: AppTheme.light,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale('es'),
          Locale('en'),
        ],
        locale: const Locale('es'),
        // Limita cuánto puede crecer el texto por la preferencia de tamaño
        // de fuente del sistema.
        //
        // Buena parte de las pantallas tiene alturas y anchos fijos, así que
        // con la fuente del teléfono muy grande el contenido se sale de su
        // caja y Flutter pinta las franjas amarillas de desbordamiento. Se
        // vio en un Honor pero no en el emulador, que va al 100%.
        //
        // 1.3 es un punto medio: sigue respetando a quien necesita el texto
        // más grande, pero evita que la app se rompa en accesibilidad
        // extrema. No sustituye a arreglar los diseños rígidos uno a uno,
        // solo acota el daño mientras tanto.
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: child!,
        ),
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
