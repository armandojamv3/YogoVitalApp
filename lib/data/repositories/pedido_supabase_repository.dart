import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/direccion_model.dart';
import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_local_model.dart';

class PedidoSupabaseRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw Exception('Usuario no autenticado');
    return id;
  }

  // ── Direcciones ──────────────────────────────────────────────────────────

  /// HU_25: obtener direcciones del cliente autenticado
  Future<List<DireccionModel>> getDirecciones() async {
    final data = await _db
        .from('direcciones')
        .select()
        .eq('cliente_id', _uid)
        .order('es_principal', ascending: false)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => DireccionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// HU_24: registrar nueva dirección
  Future<DireccionModel> addDireccion({
    required String direccion,
    required String barrio,
    required String telefono,
  }) async {
    final row = await _db.from('direcciones').insert({
      'cliente_id': _uid,
      'direccion': direccion,
      'barrio': barrio,
      'telefono': telefono,
    }).select().single();
    return DireccionModel.fromJson(row);
  }

  /// HU_25: marcar dirección como principal
  Future<void> setPrincipal(String id) async {
    // quitar principal actual
    await _db
        .from('direcciones')
        .update({'es_principal': false})
        .eq('cliente_id', _uid);
    // asignar nueva principal
    await _db
        .from('direcciones')
        .update({'es_principal': true})
        .eq('id', id)
        .eq('cliente_id', _uid);
  }

  // ── Pedidos ──────────────────────────────────────────────────────────────

  /// HU_21: confirmar pedido — inserta pedido + ingredientes + historial
  Future<String> createPedido({
    required PedidoLocalModel pedidoLocal,
    required String direccionId,
    required String metodoPago,
  }) async {
    if (metodoPago.isEmpty) {
      throw Exception('Método de pago es obligatorio');
    }

    final uid = _uid;

    // 1. INSERT pedido
    final pedidoRow = await _db.from('pedidos').insert({
      'cliente_id': uid,
      'direccion_id': direccionId,
      'tamano_id': pedidoLocal.tamano!.id,
      'sabor_id': pedidoLocal.sabor!.id,
      'estado': 'Recibido',
      'total': pedidoLocal.total,
      'metodo_pago': metodoPago, // Siempre se inserta
    }).select().single();

    final pedidoId = pedidoRow['id'] as String;

    // 2. INSERT pedido_frutas
    if (pedidoLocal.frutas.isNotEmpty) {
      await _db.from('pedido_frutas').insert(
        pedidoLocal.frutas
            .map((f) => {'pedido_id': pedidoId, 'fruta_id': f.id})
            .toList(),
      );
    }

    // 3. INSERT pedido_extras
    if (pedidoLocal.extras.isNotEmpty) {
      await _db.from('pedido_extras').insert(
        pedidoLocal.extras
            .map((e) => {'pedido_id': pedidoId, 'extra_id': e.id})
            .toList(),
      );
    }

    // 4. INSERT historial_estados (primer estado)
    await _db.from('historial_estados').insert({
      'pedido_id': pedidoId,
      'estado_nuevo': 'Recibido',
    });

    return pedidoId;
  }

  /// Crea un pedido desde el carrito (sin tamano_id obligatorio).
  /// Requiere que tamano_id sea nullable en la BD.
  Future<String> createPedidoFromCartItem({
    String? saborId,
    required String direccionId,
    required double total,
    required String metodoPago,
  }) async {
    if (metodoPago.isEmpty) {
      throw Exception('Método de pago es obligatorio');
    }

    final pedidoRow = await _db.from('pedidos').insert({
      'cliente_id': _uid,
      'direccion_id': direccionId,
      if (saborId != null && saborId.isNotEmpty) 'sabor_id': saborId,
      'estado': 'Recibido',
      'total': total,
      'metodo_pago': metodoPago, // Siempre se inserta
    }).select().single();

    final pedidoId = pedidoRow['id'] as String;

    await _db.from('historial_estados').insert({
      'pedido_id': pedidoId,
      'estado_nuevo': 'Recibido',
    });

    return pedidoId;
  }

  /// HU_26: stream Realtime del estado del pedido
  Stream<Pedido?> streamPedido(String pedidoId) {
    return _db
        .from('pedidos')
        .stream(primaryKey: ['id'])
        .eq('id', pedidoId)
        .map((list) {
          if (list.isEmpty) return null;
          return Pedido.fromJson(list.first);
        });
  }

  /// HU_23: cancelar pedido solo si estado == 'Recibido'
  Future<void> cancelarPedido(String pedidoId) async {
    final uid = _uid;

    // Verificar estado actual
    final row = await _db
        .from('pedidos')
        .select('estado')
        .eq('id', pedidoId)
        .eq('cliente_id', uid)
        .single();

    final estadoActual = row['estado'] as String;
    if (estadoActual != 'Recibido') {
      throw const _PedidoException(
        'Este pedido ya está en proceso y no puede ser cancelado.',
      );
    }

    await _db
        .from('pedidos')
        .update({'estado': 'Cancelado', 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', pedidoId)
        .eq('cliente_id', uid);

    await _db.from('historial_estados').insert({
      'pedido_id': pedidoId,
      'estado_anterior': 'Recibido',
      'estado_nuevo': 'Cancelado',
    });
  }

  /// HU_28 (historial): pedidos del cliente ordenados por fecha
  Future<List<Pedido>> getHistorial() async {
    final data = await _db
        .from('pedidos')
        .select()
        .eq('cliente_id', _uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Pedido.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class _PedidoException implements Exception {
  final String message;
  const _PedidoException(this.message);

  @override
  String toString() => message;
}
