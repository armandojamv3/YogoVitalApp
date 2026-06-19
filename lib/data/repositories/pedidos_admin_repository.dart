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

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const PedidoAdminException('Usuario no autenticado');
    return id;
  }

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
      id, estado, total, created_at, updated_at, cliente_id, direccion_id,
      tamanos_yogur(nombre),
      sabores(nombre)
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
    final nombres = await _getNombresClientes(clienteIds);

    // Inyecta el nombre en cada fila para que PedidoAdmin.fromRow lo lea
    for (final r in rows) {
      r['usuarios'] = {'nombre': nombres[r['cliente_id']?.toString()]};
    }

    return rows.map(PedidoAdmin.fromRow).toList();
  }

  /// Devuelve un mapa cliente_id -> nombre para la lista de ids dada.
  /// Lookup separado en lugar de embed `usuarios!cliente_id(...)`, que
  /// dependía de relaciones/RLS frágiles.
  Future<Map<String, String>> _getNombresClientes(
      List<String> clienteIds) async {
    if (clienteIds.isEmpty) return {};
    final response = await _db
        .from('usuarios')
        .select('id, nombre')
        .inFilter('id', clienteIds);
    return {
      for (final row in (response as List))
        row['id'].toString(): (row['nombre'] as String?) ?? '',
    };
  }

  // ── Detalle completo de un pedido (HU_37) ────────────────────────────────

  Future<PedidoAdminDetalle> getDetalle(String pedidoId) async {
    try {
      final data = await _db.from('pedidos').select('''
        id, estado, total, created_at, updated_at, cliente_id, direccion_id,
        tamanos_yogur(nombre, precio),
        sabores(nombre),
        pedido_frutas(frutas(nombre, precio_adicional)),
        pedido_extras(extras(nombre, precio_adicional)),
        historial_estados(id, estado_anterior, estado_nuevo, fecha_cambio),
        direcciones(direccion, barrio)
      ''').eq('id', pedidoId).single();

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

    final uid = _uid;

    // PASO 1: UPDATE pedido
    await _db.from('pedidos').update({
      'estado': estadoNuevo,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', pedidoId);

    // PASO 2: INSERT historial (RNF09 trazabilidad)
    await _db.from('historial_estados').insert({
      'pedido_id': pedidoId,
      'estado_anterior': estadoActual,
      'estado_nuevo': estadoNuevo,
      'admin_id': uid,
    });

    // PASO 3: Push notification (best-effort, no falla el flujo principal)
    try {
      await _db.functions.invoke(
        'send-notification',
        body: {
          'cliente_id': clienteId,
          'nuevo_estado': estadoNuevo,
          'pedido_id': pedidoId,
        },
      );
    } catch (_) {
      // Best-effort: no interrumpir si la Edge Function no responde
    }
  }
}
