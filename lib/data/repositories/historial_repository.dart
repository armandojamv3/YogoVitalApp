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

  /// Lista de pedidos del cliente con nombre de sabor y tamaño.
  Future<List<PedidoHistorial>> getPedidos() async {
    try {
      final data = await _db
          .from('pedidos')
          .select('id, estado, total, created_at, sabores(nombre), tamanos_yogur(nombre)')
          .eq('cliente_id', _uid)
          .order('created_at', ascending: false);

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
