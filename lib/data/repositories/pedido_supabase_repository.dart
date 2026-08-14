import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Manda una push a los administradores.
  ///
  /// La notificación in-app ya la escriben las RPC `crear_pedido` y
  /// `cancelar_pedido` dentro de su transacción; esto es el otro canal, el
  /// que hace sonar el teléfono con la app cerrada. No puede hacerlo la
  /// función de Postgres: no sabe llamar a una Edge Function.
  ///
  /// Solo se manda el evento y el id: **el texto lo compone la Edge
  /// Function** leyendo el pedido real. Si lo armara aquí, el mensaje
  /// llevaría la idea que tiene la app del precio, que no siempre coincide
  /// con lo que cobró el servidor — esa discrepancia es justo el bug que
  /// arregló la migración 0043.
  ///
  /// Es best-effort a propósito. Si FCM no responde, el pedido ya está
  /// creado y el aviso in-app guardado; interrumpir aquí sería peor.
  ///
  /// La Edge Function resuelve quiénes son los administradores por su
  /// cuenta: el cliente nunca recibe esos ids.
  Future<void> _avisarAlNegocio({
    required String evento, // 'nuevo' | 'cancelado'
    required String pedidoId,
  }) async {
    try {
      await _db.functions.invoke('send-notification', body: {
        'destino': 'administradores',
        'evento': evento,
        'pedido_id': pedidoId,
      });
    } catch (e) {
      debugPrint('[Pedidos] No se pudo enviar la push al negocio: $e');
    }
  }

  /// HU_21: confirmar pedido personalizado.
  ///
  /// Delega en la RPC `crear_pedido` (migración 0043). Antes esto eran 4
  /// INSERT sueltos (pedidos → pedido_frutas → pedido_extras →
  /// historial_estados), lo que causaba dos problemas:
  ///
  ///  * Desde la migración 0041, el total se guardaba SIN frutas ni extras.
  ///    El trigger BEFORE INSERT los suma leyendo pedido_frutas/pedido_extras,
  ///    que en ese instante siguen vacías. La 0035 lo compensaba tocando la
  ///    fila del pedido después de insertar los ingredientes, pero la 0041
  ///    limitó ese recálculo a los UPDATE que cambian `tamano_id` — y el
  ///    "toque" no cambia tamano_id, así que dejó de funcionar.
  ///  * Si fallaba cualquiera de los INSERT posteriores, el pedido quedaba
  ///    huérfano (sin ingredientes o sin historial).
  ///
  /// La RPC hace todo en una sola transacción y calcula el total leyendo
  /// los precios del catálogo. [PedidoLocalModel.total] sigue existiendo,
  /// pero ya solo sirve para mostrar el precio en la UI: el importe real
  /// lo decide el servidor.
  Future<String> createPedido({
    required PedidoLocalModel pedidoLocal,
    required String direccionId,
    required String metodoPago,
  }) async {
    if (metodoPago.isEmpty) {
      throw Exception('Método de pago es obligatorio');
    }
    if (pedidoLocal.tamano == null) {
      throw Exception('Debes elegir un tamaño');
    }
    if (pedidoLocal.sabor == null) {
      throw Exception('Debes elegir un sabor');
    }

    final id = await _db.rpc('crear_pedido', params: {
      'p_direccion_id': direccionId,
      'p_metodo_pago': metodoPago,
      'p_tamano_id': pedidoLocal.tamano!.id,
      'p_sabor_id': pedidoLocal.sabor!.id,
      'p_dulzura': pedidoLocal.dulzura,
      'p_frutas': pedidoLocal.frutas.map((f) => f.id).toList(),
      'p_extras': pedidoLocal.extras.map((e) => e.id).toList(),
    });

    final pedidoId = id?.toString() ?? '';
    if (pedidoId.isEmpty) {
      throw Exception('No se pudo crear el pedido');
    }

    await _avisarAlNegocio(evento: 'nuevo', pedidoId: pedidoId);
    return pedidoId;
  }

  /// Crea un pedido a partir de un ítem del carrito.
  ///
  /// Un ítem del carrito es o bien un **prediseñado** ([predisenhadoId]) o
  /// bien un **sabor suelto** ([saborId]) — nunca los dos. El precio ya no
  /// viaja desde la app: la RPC lo lee del catálogo (`predisenhados.precio_total`
  /// o `sabores.precio_base`) y lo multiplica por [cantidad]. Antes se
  /// insertaba el total tal cual lo mandaba el cliente, así que era posible
  /// crear un pedido con total 0.
  Future<String> createPedidoDesdeCarrito({
    String? saborId,
    String? predisenhadoId,
    String? tamanoId,
    required String direccionId,
    required String metodoPago,
    int cantidad = 1,
  }) async {
    if (metodoPago.isEmpty) {
      throw Exception('Método de pago es obligatorio');
    }
    final esPredisenhado =
        predisenhadoId != null && predisenhadoId.isNotEmpty;

    if (!esPredisenhado && (saborId == null || saborId.isEmpty)) {
      throw Exception('El ítem del carrito no tiene sabor ni prediseñado');
    }
    // Desde la migración 0045 el tamaño es obligatorio en un prediseñado:
    // el precio es la receta más el tamaño. Se comprueba aquí para dar un
    // mensaje claro en vez de dejar que reviente la RPC.
    if (esPredisenhado && (tamanoId == null || tamanoId.isEmpty)) {
      throw Exception('Debes elegir un tamaño para el prediseñado');
    }

    final id = await _db.rpc('crear_pedido', params: {
      'p_direccion_id': direccionId,
      'p_metodo_pago': metodoPago,
      if (esPredisenhado)
        'p_predisenhado_id': predisenhadoId
      else
        'p_sabor_id': saborId,
      if (tamanoId != null && tamanoId.isNotEmpty) 'p_tamano_id': tamanoId,
      'p_cantidad': cantidad,
    });

    final pedidoId = id?.toString() ?? '';
    if (pedidoId.isEmpty) {
      throw Exception('No se pudo crear el pedido');
    }

    await _avisarAlNegocio(evento: 'nuevo', pedidoId: pedidoId);
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

  /// HU_23: cancelar pedido, solo si sigue en 'Recibido'.
  ///
  /// Delega en la RPC `cancelar_pedido` (migración 0047). Antes eran tres
  /// operaciones sueltas —comprobar el estado, actualizar el pedido,
  /// escribir el historial— con tres problemas:
  ///
  ///  * Nadie avisaba al administrador. Podía estar preparando un yogur ya
  ///    cancelado.
  ///  * No era atómico: si fallaba el historial, el pedido quedaba
  ///    cancelado sin rastro de cuándo.
  ///  * Entre la comprobación y el UPDATE, el admin podía mover el pedido a
  ///    'En preparación'. La RPC bloquea la fila mientras decide, así que
  ///    esa carrera ya no existe.
  ///
  /// Los mensajes de error vienen de la función y ya son legibles para el
  /// usuario, así que se reenvían tal cual.
  Future<void> cancelarPedido(String pedidoId) async {
    try {
      await _db.rpc('cancelar_pedido', params: {'p_pedido_id': pedidoId});
    } on PostgrestException catch (e) {
      throw _PedidoException(e.message);
    }
    await _avisarAlNegocio(evento: 'cancelado', pedidoId: pedidoId);
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
