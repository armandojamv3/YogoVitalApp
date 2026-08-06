import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yogo_vital_app/core/models/factura_model.dart';

class FacturaException implements Exception {
  final String message;
  const FacturaException(this.message);
  @override
  String toString() => 'FacturaException: $message';
}

/// Repositorio para HU_DetalleFactura_31.
/// Query completa con JOINs a tamanos, sabores, frutas y extras.
class FacturaRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const FacturaException('Usuario no autenticado');
    return id;
  }

  Future<FacturaModel> getFactura(String pedidoId) async {
    try {
      final data = await _db
          .from('pedidos')
          .select('''
            id, total, created_at, estado, cantidad, costo_envio,
            tamanos_yogur(nombre, precio),
            sabores(nombre),
            predisenhados(nombre, ingredientes),
            pedido_frutas(frutas(nombre, precio_adicional)),
            pedido_extras(extras(nombre, precio_adicional))
          ''')
          .eq('id', pedidoId)
          .eq('cliente_id', _uid)
          .single();

      return FacturaModel.fromSupabaseRow(data);
    } on PostgrestException catch (e) {
      throw FacturaException('No se pudo cargar la factura: ${e.message}');
    } catch (e) {
      throw FacturaException('Error inesperado: $e');
    }
  }
}
