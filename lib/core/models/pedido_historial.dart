import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/utils/id_format.dart';

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

  /// El pedido salió de un prediseñado, no del personalizador.
  final bool esPredisenhado;

  /// Receta del prediseñado (columna `ingredientes`, lista de textos).
  ///
  /// Un prediseñado no genera filas en pedido_frutas/pedido_extras: es un
  /// producto cerrado y su contenido vive en esa lista. Sin esto el
  /// historial mostraba solo el nombre, sin decir qué trae dentro.
  final List<String> ingredientes;

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
    this.esPredisenhado = false,
    this.ingredientes = const [],
  });

  /// Línea de resumen para las tarjetas del listado. Omite lo que esté
  /// vacío, para no dejar separadores sueltos como "Tropical Explosión · ".
  String get resumenLinea =>
      [saborNombre, tamanoNombre].where((s) => s.isNotEmpty).join(' · ');

  EstadoPedido get estado => EstadoPedidoExtension.fromString(estadoRaw);

  /// ID corto para mostrar al usuario (ej. #AB12).
  String get idCorto => '#${shortId(id)}';

  factory PedidoHistorial.fromSupabaseRow(Map<String, dynamic> row) {
    final saborMap = row['sabores'] as Map<String, dynamic>? ?? {};
    final tamanoMap = row['tamanos_yogur'] as Map<String, dynamic>? ?? {};

    // Un pedido de prediseñado no tiene sabor ni tamaño propios (ambos
    // quedan NULL, ver migración 0043): el producto es el prediseñado
    // entero. Sin esto el pedido salía en pantalla con el nombre vacío.
    final predisenhadoMap =
        row['predisenhados'] as Map<String, dynamic>? ?? {};
    final nombrePredisenhado = predisenhadoMap['nombre'] as String? ?? '';
    final esPred = nombrePredisenhado.isNotEmpty;

    final ingredientes = (predisenhadoMap['ingredientes'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

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
      saborNombre:
          esPred ? nombrePredisenhado : (saborMap['nombre'] as String? ?? ''),
      // Desde la migración 0045 un prediseñado también lleva tamaño, así
      // que se lee igual en los dos casos. Queda vacío solo en los pedidos
      // de prediseñado anteriores a esa migración, que no eligieron uno.
      tamanoNombre: tamanoMap['nombre'] as String? ?? '',
      tamanoPrice: _parseDouble(tamanoMap['precio']),
      frutas: frutasList,
      extras: extrasList,
      direccionId: row['direccion_id']?.toString(),
      esPredisenhado: esPred,
      ingredientes: ingredientes,
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
