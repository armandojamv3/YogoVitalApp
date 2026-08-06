import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/notificacion.dart';

/// Notificaciones dentro de la app (in-app), en tiempo real vía Supabase
/// Realtime. No depende de Firebase/FCM ni de ningún servicio externo.
class NotificacionesRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String? get _uid => _db.auth.currentUser?.id;

  // Esquema real en Supabase: usuario_id / leida (no cliente_id / leido
  // como el resto del proyecto — esta tabla ya existía de un sprint
  // anterior con estos nombres de columna).

  /// Stream con todas las notificaciones del cliente autenticado.
  /// Se usa tanto para el contador de no leídas (badge) como para el
  /// listado completo.
  Stream<List<Notificacion>> streamNotificaciones() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _db
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .eq('usuario_id', uid)
        .map((rows) {
          final list = rows.map(Notificacion.fromJson).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Marca todas las notificaciones no leídas del cliente como leídas
  /// (se llama al abrir la pantalla de notificaciones).
  Future<void> marcarTodasLeidas() async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('notificaciones')
        .update({'leida': true})
        .eq('usuario_id', uid)
        .eq('leida', false);
  }

  /// Crea una notificación para un cliente. La usa el admin al cambiar el
  /// estado de un pedido (ver PedidosAdminRepository.cambiarEstado).
  Future<void> crear({
    required String clienteId,
    required String mensaje,
    String titulo = 'Yogo Vital',
    String tipo = 'pedido',
    String? pedidoId,
  }) async {
    await _db.from('notificaciones').insert({
      'usuario_id': clienteId,
      'pedido_id': pedidoId,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'leida': false,
    });
  }
}
