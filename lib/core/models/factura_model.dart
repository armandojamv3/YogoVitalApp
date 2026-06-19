import 'package:yogo_vital_app/core/models/pedido_historial.dart';
import 'package:yogo_vital_app/core/utils/id_format.dart';

/// Modelo completo de factura para HU_DetalleFactura_31.
class FacturaModel {
  final String pedidoId;
  final String idCorto;
  final DateTime createdAt;
  final String estado;
  final String tamanoNombre;
  final double tamanoPrice;
  final String saborNombre;
  final List<IngredienteDetalle> frutas;
  final List<IngredienteDetalle> extras;
  final double costoEnvio;

  const FacturaModel({
    required this.pedidoId,
    required this.idCorto,
    required this.createdAt,
    required this.estado,
    required this.tamanoNombre,
    required this.tamanoPrice,
    required this.saborNombre,
    required this.frutas,
    required this.extras,
    required this.costoEnvio,
  });

  /// Suma de los ítems del pedido: tamaño + frutas + extras.
  double get subtotal =>
      tamanoPrice +
      frutas.fold(0.0, (s, f) => s + f.precio) +
      extras.fold(0.0, (s, e) => s + e.precio);

  /// Total a pagar: subtotal de ítems + costo de envío.
  double get total => subtotal + costoEnvio;

  factory FacturaModel.fromSupabaseRow(Map<String, dynamic> row,
      {double costoEnvio = 3000}) {
    final id = row['id']?.toString() ?? '';
    final tamanoMap = row['tamanos_yogur'] as Map<String, dynamic>? ?? {};
    final saborMap = row['sabores'] as Map<String, dynamic>? ?? {};

    final frutas = (row['pedido_frutas'] as List? ?? [])
        .map((pf) {
          final f = pf['frutas'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: f['nombre'] as String? ?? '',
            precio: _parseDouble(f['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    final extras = (row['pedido_extras'] as List? ?? [])
        .map((pe) {
          final e = pe['extras'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: e['nombre'] as String? ?? '',
            precio: _parseDouble(e['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    return FacturaModel(
      pedidoId: id,
      idCorto: '#${shortId(id)}',
      createdAt: _parseDate(row['created_at']),
      estado: row['estado'] as String? ?? '',
      tamanoNombre: tamanoMap['nombre'] as String? ?? '',
      tamanoPrice: _parseDouble(tamanoMap['precio']),
      saborNombre: saborMap['nombre'] as String? ?? '',
      frutas: frutas,
      extras: extras,
      costoEnvio: costoEnvio,
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
