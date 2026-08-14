import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/pedido_admin.dart';

class PedidoAdminException implements Exception {
  final String message;
  const PedidoAdminException(this.message);
  @override
  String toString() => message;
}

/// Repositorio para el panel admin de pedidos (Sprint 8).
/// Supabase Realtime + trazabilidad RNF09.
class PedidosAdminRepository {
  SupabaseClient get _db => Supabase.instance.client;

  // Antes había aquí un getter _uid que solo servía para rellenar admin_id
  // al escribir el historial a mano. Ahora ese dato lo pone el trigger
  // registrar_cambio_estado, que además solo lo rellena si quien cambia el
  // estado es de verdad un administrador (ver migración 0048).

  // ── Transiciones válidas (HU_CambiarEstadoPedido_37) ─────────────────────

  static const Map<String, List<String>> _transiciones = {
    'Recibido': ['En preparación', 'Cancelado'],
    'En preparación': ['En camino'],
    'En camino': ['Entregado'],
    'Entregado': [],
    'Cancelado': [],
  };

  static bool validarTransicion(String estadoActual, String estadoNuevo) {
    return _transiciones[estadoActual]?.contains(estadoNuevo) ?? false;
  }

  // Los textos de la notificación que ve el cliente vivían aquí duplicados
  // con los del trigger crear_notificacion_cambio_estado. Se eliminaron
  // junto con el INSERT que los usaba: la fuente única es ahora el trigger
  // (ver migración 0048). Si hay que cambiar un mensaje, se cambia allí.

  /// Texto de la notificación push que ve el cliente.
  ///
  /// Duplica a propósito los mensajes del trigger
  /// crear_notificacion_cambio_estado: aquel escribe la notificación in-app
  /// en la base, este viaja a FCM. Son dos canales distintos y el trigger no
  /// puede llamar a la Edge Function.
  static String _cuerpoPush(String estado) {
    switch (estado) {
      case 'En preparación':
        return 'Tu yogur está siendo preparado 🍶';
      case 'En camino':
        return 'Tu pedido está en camino 🛵';
      case 'Entregado':
        return '¡Tu pedido ha llegado! Disfrútalo 🎉';
      case 'Cancelado':
        return 'Tu pedido fue cancelado';
      default:
        return 'El estado de tu pedido cambió a: $estado';
    }
  }

  static List<String> estadosSiguientes(String estadoActual) {
    return _transiciones[estadoActual] ?? [];
  }

  // ── Stream con Realtime (HU_VerPedidosAdmin_36) ───────────────────────────

  Stream<List<PedidoAdmin>> streamTodosPedidos(
      {DateTime? desde, DateTime? hasta}) {
    late final StreamController<List<PedidoAdmin>> controller;
    RealtimeChannel? channel;

    void fetch() {
      _fetchPedidos(desde: desde, hasta: hasta)
          .then((d) {
            if (!controller.isClosed) controller.add(d);
          })
          .catchError((e) {
            if (!controller.isClosed) controller.addError(e);
          });
    }

    controller = StreamController<List<PedidoAdmin>>(
      onListen: () {
        fetch();
        channel = _db
            .channel('pedidos_admin_${DateTime.now().millisecondsSinceEpoch}')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'pedidos',
              callback: (_) => fetch(),
            )
            .subscribe();
      },
      onCancel: () {
        if (channel != null) _db.removeChannel(channel!);
        controller.close();
      },
    );

    return controller.stream;
  }

  // ── Fetch con JOIN (base de la query) ─────────────────────────────────────

  Future<List<PedidoAdmin>> _fetchPedidos(
      {DateTime? desde, DateTime? hasta}) async {
    var q = _db.from('pedidos').select('''
      id, estado, total, created_at, updated_at, cliente_id, direccion_id, dulzura, cantidad,
      tamanos_yogur(nombre),
      sabores(nombre),
      predisenhados(nombre, ingredientes)
    ''');

    if (desde != null) q = q.gte('created_at', desde.toIso8601String());
    if (hasta != null) {
      final fin = DateTime(hasta.year, hasta.month, hasta.day, 23, 59, 59);
      q = q.lte('created_at', fin.toIso8601String());
    }

    final data = await q.order('created_at', ascending: false);
    final rows = (data as List).cast<Map<String, dynamic>>();

    // Plan B: nombres de clientes en un lookup separado (sin embed de usuarios)
    final clienteIds = rows
        .map((r) => r['cliente_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final clientes = await _getDatosClientes(clienteIds);

    // Inyecta nombre + teléfono en cada fila para que PedidoAdmin.fromRow lo lea
    for (final r in rows) {
      final info = clientes[r['cliente_id']?.toString()];
      r['usuarios'] = {
        'nombre': info?['nombre'],
        'telefono': info?['telefono'],
      };
    }

    return rows.map(PedidoAdmin.fromRow).toList();
  }

  /// Devuelve un mapa cliente_id -> {nombre, telefono} para los ids dados.
  /// Lookup separado en lugar de embed `usuarios!cliente_id(...)`, que
  /// dependía de relaciones/RLS frágiles.
  Future<Map<String, Map<String, String?>>> _getDatosClientes(
      List<String> clienteIds) async {
    if (clienteIds.isEmpty) return {};
    final response = await _db
        .from('usuarios')
        .select('id, nombre, telefono')
        .inFilter('id', clienteIds);
    return {
      for (final row in (response as List))
        row['id'].toString(): {
          'nombre': row['nombre'] as String?,
          'telefono': row['telefono'] as String?,
        },
    };
  }

  // ── Detalle completo de un pedido (HU_37) ────────────────────────────────

  Future<PedidoAdminDetalle> getDetalle(String pedidoId) async {
    try {
      final data = await _db.from('pedidos').select('''
        id, estado, total, created_at, updated_at, cliente_id, direccion_id, dulzura, cantidad,
        tamanos_yogur(nombre, precio),
        sabores(nombre),
        predisenhados(nombre, ingredientes),
        pedido_frutas(frutas(nombre, precio_adicional)),
        pedido_extras(extras(nombre, precio_adicional)),
        historial_estados(id, estado_anterior, estado_nuevo, fecha_cambio),
        direcciones(direccion, barrio, telefono)
      ''').eq('id', pedidoId).single();

      // Plan B: lookup separado del nombre/teléfono del cliente (sin embed de usuarios)
      final clienteId = data['cliente_id']?.toString();
      if (clienteId != null && clienteId.isNotEmpty) {
        final clientes = await _getDatosClientes([clienteId]);
        data['usuarios'] = clientes[clienteId] ?? {};
      }

      return PedidoAdminDetalle.fromRow(data);
    } on PostgrestException catch (e) {
      throw PedidoAdminException('No se pudo cargar el pedido: ${e.message}');
    }
  }

  // ── Contadores por estado ────────────────────────────────────────────────

  Future<Map<String, int>> getContadoresEstado() async {
    try {
      final data = await _db.from('pedidos').select('estado');
      final Map<String, int> counters = {
        'Recibido': 0,
        'En preparación': 0,
        'En camino': 0,
        'Entregado': 0,
        'Cancelado': 0,
      };
      for (final row in (data as List)) {
        final e = row['estado'] as String? ?? '';
        if (counters.containsKey(e)) counters[e] = counters[e]! + 1;
      }
      return counters;
    } catch (_) {
      return {};
    }
  }

  // ── Cambiar estado (HU_CambiarEstadoPedido_37) ───────────────────────────

  Future<void> cambiarEstado({
    required String pedidoId,
    required String clienteId,
    required String estadoActual,
    required String estadoNuevo,
  }) async {
    if (!validarTransicion(estadoActual, estadoNuevo)) {
      throw PedidoAdminException(
          'Transición no permitida: $estadoActual → $estadoNuevo');
    }

    // PASO 1: UPDATE pedido
    try {
      final rows = await _db
          .from('pedidos')
          .update({
            'estado': estadoNuevo,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId)
          .select('id');

      // Si RLS bloquea el UPDATE sin lanzar excepción (política que no
      // matchea), Postgrest simplemente devuelve 0 filas afectadas. Sin
      // este chequeo, eso se veía como "no pasó nada" sin ningún error.
      if ((rows as List).isEmpty) {
        throw const PedidoAdminException(
            'No se pudo actualizar el pedido: no tienes permiso o el pedido ya no existe.');
      }
    } on PedidoAdminException {
      rethrow;
    } on PostgrestException catch (e) {
      throw PedidoAdminException('No se pudo actualizar el pedido: ${e.message}');
    }

    // El historial y la notificación al cliente los escriben dos triggers
    // sobre `pedidos` que dispara el UPDATE de arriba:
    //
    //   trg_registrar_cambio_estado         → historial_estados
    //   trg_crear_notificacion_cambio_estado → notificaciones
    //
    // Aquí se insertaban también, así que cada cambio de estado dejaba dos
    // filas de historial y le mandaba dos avisos idénticos al cliente. Los
    // triggers existían en la base pero no en ninguna migración del repo,
    // por eso nadie lo vio hasta la revisión del 6 de agosto (ver 0048).
    //
    // Se dejan los triggers y se quita esto: un trigger cubre también los
    // cambios hechos desde el editor SQL o desde cualquier función futura,
    // que es lo que hace falta para la trazabilidad del RNF09.

    // Push notification (best-effort, no falla el flujo principal).
    // Nota: hoy no llega a ningún lado porque la app no tiene integrado
    // Firebase/FCM (ver notificaciones in-app arriba, que sí funcionan).
    try {
      await _db.functions.invoke(
        'send-notification',
        body: {
          'usuario_id': clienteId,
          'titulo': 'Actualización de pedido',
          'cuerpo': _cuerpoPush(estadoNuevo),
          'pedido_id': pedidoId,
        },
      );
    } catch (_) {
      // Best-effort: no interrumpir si la Edge Function no responde
    }
  }
}
