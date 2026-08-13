import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/pedido_historial.dart';

class HistorialException implements Exception {
  final String message;
  const HistorialException(this.message);
  @override
  String toString() => 'HistorialException: $message';
}

/// Repositorio para HU_HistorialPedidos_28.
/// Usa Supabase con JOINs a sabores, tamanos, frutas y extras.
class HistorialRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const HistorialException('Usuario no autenticado');
    return id;
  }

  /// Cuántos pedidos se traen por página.
  ///
  /// Los pedidos no se borran nunca —son registros de venta—, así que un
  /// cliente habitual acumula cientos con el tiempo. Antes se traían todos
  /// de golpe en cada apertura de la pantalla: lento, y con datos que nadie
  /// llega a mirar.
  static const int pedidosPorPagina = 20;

  /// Página [pagina] (empezando en 0) de los pedidos del cliente, del más
  /// reciente al más antiguo.
  ///
  /// Devolver menos de [porPagina] elementos significa que no hay más.
  Future<List<PedidoHistorial>> getPedidos({
    int pagina = 0,
    int porPagina = pedidosPorPagina,
  }) async {
    final desde = pagina * porPagina;
    final hasta = desde + porPagina - 1;
    try {
      final data = await _db
          .from('pedidos')
          .select('id, estado, total, created_at, sabores(nombre), tamanos_yogur(nombre), predisenhados(nombre, ingredientes)')
          .eq('cliente_id', _uid)
          .order('created_at', ascending: false)
          .range(desde, hasta);

      return (data as List)
          .map((row) => PedidoHistorial.fromSupabaseRow(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw HistorialException('No se pudo cargar el historial: $e');
    }
  }

  /// Detalle completo de un pedido: frutas, extras, estado, dirección.
  Future<PedidoHistorial> getDetalle(String pedidoId) async {
    try {
      final data = await _db
          .from('pedidos')
          .select('''
            id, estado, total, created_at, direccion_id,
            sabores(nombre),
            predisenhados(nombre, ingredientes),
            tamanos_yogur(nombre, precio),
            pedido_frutas(frutas(nombre, precio_adicional)),
            pedido_extras(extras(nombre, precio_adicional))
          ''')
          .eq('id', pedidoId)
          .eq('cliente_id', _uid)
          .single();

      return PedidoHistorial.fromSupabaseRow(data);
    } catch (e) {
      throw HistorialException('No se pudo cargar el detalle del pedido: $e');
    }
  }
}
