import 'package:yogo_vital_app/core/models/pedido.dart';

/// Pedido enriquecido con nombres de sabor y tamaño para la pantalla historial.
class PedidoHistorial {
  final String id;
  final String estadoRaw;
  final double total;
  final DateTime createdAt;
  final String saborNombre;
  final String tamanoNombre;
  final double tamanoPrice;
  final List<IngredienteDetalle> frutas;
  final List<IngredienteDetalle> extras;
  final String? direccionId;

  const PedidoHistorial({
    required this.id,
    required this.estadoRaw,
    required this.total,
    required this.createdAt,
    required this.saborNombre,
    required this.tamanoNombre,
    this.tamanoPrice = 0,
    this.frutas = const [],
    this.extras = const [],
    this.direccionId,
  });

  EstadoPedido get estado => EstadoPedidoExtension.fromString(estadoRaw);

  /// ID corto para mostrar al usuario (ej. #AB12).
  String get idCorto => '#${id.substring(0, 8).toUpperCase()}';

  factory PedidoHistorial.fromSupabaseRow(Map<String, dynamic> row) {
    final saborMap = row['sabores'] as Map<String, dynamic>? ?? {};
    final tamanoMap = row['tamanos'] as Map<String, dynamic>? ?? {};

    final frutasList = (row['pedido_frutas'] as List? ?? [])
        .map((pf) {
          final f = pf['frutas'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: f['nombre'] as String? ?? '',
            precio: _parseDouble(f['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    final extrasList = (row['pedido_extras'] as List? ?? [])
        .map((pe) {
          final e = pe['extras'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: e['nombre'] as String? ?? '',
            precio: _parseDouble(e['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    return PedidoHistorial(
      id: row['id']?.toString() ?? '',
      estadoRaw: row['estado'] as String? ?? 'Desconocido',
      total: _parseDouble(row['total']),
      createdAt: _parseDate(row['created_at']),
      saborNombre: saborMap['nombre'] as String? ?? '',
      tamanoNombre: tamanoMap['nombre'] as String? ?? '',
      tamanoPrice: _parseDouble(tamanoMap['precio']),
      frutas: frutasList,
      extras: extrasList,
      direccionId: row['direccion_id']?.toString(),
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

class IngredienteDetalle {
  final String nombre;
  final double precio;

  const IngredienteDetalle({required this.nombre, required this.precio});
}
