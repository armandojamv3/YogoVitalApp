import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manejador de mensajes con la app en segundo plano o cerrada.
///
/// Tiene que ser una función de nivel superior y estar anotada con
/// `@pragma('vm:entry-point')`: Android la ejecuta en un isolate propio, sin
/// el árbol de widgets ni el estado de la app. Si fuera un método de clase,
/// el compilador en modo release podría descartarla y las notificaciones
/// dejarían de llegar solo en release, que es de los fallos más difíciles
/// de diagnosticar.
///
/// No hace falta pintar nada aquí: cuando la app no está en primer plano,
/// Android dibuja la notificación por su cuenta a partir del bloque
/// `notification` del mensaje.
@pragma('vm:entry-point')
Future<void> manejarMensajeEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp();
  debugPrint('[Push] Mensaje en segundo plano: ${mensaje.messageId}');
}

/// Notificaciones push (FCM).
///
/// Complementa a las notificaciones in-app que se guardan en Supabase
/// (migraciones 0046 y 0047): aquellas solo se ven al abrir la app, y esto
/// hace sonar el teléfono con la app cerrada. Es lo que necesita un
/// administrador para enterarse de un pedido a las ocho de la noche.
///
/// El flujo completo:
///   1. La app pide permiso y obtiene un token de FCM.
///   2. Lo guarda en `dispositivos` vía la RPC registrar_dispositivo (0049).
///   3. Al crear o cancelar un pedido, la Edge Function busca los tokens de
///      los administradores y les envía la notificación.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _canalId = 'yogo_vital_pedidos';
  static const _canalNombre = 'Pedidos';

  final _localNotifications = FlutterLocalNotificationsPlugin();

  bool _iniciado = false;
  String? _tokenActual;

  /// Token FCM de este dispositivo, si ya se obtuvo.
  String? get token => _tokenActual;

  /// Arranca Firebase y deja todo escuchando.
  ///
  /// Se llama una vez desde main(). No pide permiso todavía ni guarda el
  /// token: eso ocurre al iniciar sesión, cuando ya se sabe de quién es el
  /// dispositivo.
  Future<void> iniciar() async {
    if (_iniciado) return;

    // En web haría falta una configuración aparte (service worker y clave
    // VAPID) que no está montada. Mejor no arrancar que fallar a medias.
    if (kIsWeb) {
      debugPrint('[Push] Omitido en web: no está configurado.');
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(manejarMensajeEnSegundoPlano);
      await _configurarNotificacionesLocales();

      // Con la app en primer plano Android NO dibuja la notificación: la
      // entrega en silencio a la app. Hay que mostrarla a mano.
      FirebaseMessaging.onMessage.listen(_mostrarEnPrimerPlano);

      _iniciado = true;
      debugPrint('[Push] Iniciado.');
    } catch (e) {
      // Sin push la app sigue funcionando: las notificaciones in-app se
      // guardan igual en Supabase. No se interrumpe el arranque.
      debugPrint('[Push] No se pudo iniciar: $e');
    }
  }

  Future<void> _configurarNotificacionesLocales() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Android 8+ exige un canal declarado; si no existe, la notificación se
    // descarta sin avisar. Importance.high es lo que hace que salga como
    // aviso emergente y con sonido.
    const canal = AndroidNotificationChannel(
      _canalId,
      _canalNombre,
      description: 'Avisos de pedidos nuevos y cancelaciones',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canal);
  }

  Future<void> _mostrarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;

    await _localNotifications.show(
      mensaje.hashCode,
      aviso.title,
      aviso.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalId,
          _canalNombre,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Pide permiso, obtiene el token y lo guarda para este usuario.
  ///
  /// Se llama al iniciar sesión. En Android 13+ aquí es donde el sistema
  /// muestra el diálogo de permiso de notificaciones.
  Future<void> registrarParaUsuarioActual() async {
    if (!_iniciado) return;

    try {
      final permiso = await FirebaseMessaging.instance.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[Push] El usuario rechazó las notificaciones.');
        return;
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[Push] FCM no devolvió token.');
        return;
      }
      await _guardarToken(token);

      // FCM puede rotar el token en cualquier momento (reinstalación,
      // borrado de datos, decisión de Google). Si no se vuelve a guardar,
      // las notificaciones dejan de llegar sin ningún error visible.
      FirebaseMessaging.instance.onTokenRefresh.listen(_guardarToken);
    } catch (e) {
      debugPrint('[Push] No se pudo registrar el dispositivo: $e');
    }
  }

  Future<void> _guardarToken(String token) async {
    _tokenActual = token;
    try {
      await Supabase.instance.client.rpc('registrar_dispositivo', params: {
        'p_token': token,
        'p_plataforma': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      });
      debugPrint('[Push] Token registrado.');
    } catch (e) {
      debugPrint('[Push] No se pudo guardar el token: $e');
    }
  }

  /// Da de baja el dispositivo al cerrar sesión.
  ///
  /// Sin esto, quien inicie sesión después en este teléfono seguiría
  /// recibiendo las notificaciones de la cuenta anterior.
  Future<void> darDeBaja() async {
    final token = _tokenActual;
    if (token == null) return;
    try {
      await Supabase.instance.client
          .rpc('eliminar_dispositivo', params: {'p_token': token});
      debugPrint('[Push] Dispositivo dado de baja.');
    } catch (e) {
      debugPrint('[Push] No se pudo dar de baja el dispositivo: $e');
    }
  }
}
