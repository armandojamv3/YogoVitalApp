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

  /// Total de los ítems tal como quedó guardado en `pedidos.total`.
  ///
  /// Desde la migración 0043 lo calcula el servidor en crear_pedido(), así
  /// que es el importe real por el que se cobró el pedido.
  final double totalGuardado;

  /// Unidades pedidas. Relevante en pedidos de carrito y prediseñado.
  final int cantidad;

  /// El pedido salió de un prediseñado: producto cerrado, sin tamaño ni
  /// sabor propios, y sin líneas de frutas/extras que desglosar.
  final bool esPredisenhado;

  /// Receta del prediseñado, para desglosarla en la factura.
  final List<String> ingredientes;

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
    this.totalGuardado = 0,
    this.cantidad = 1,
    this.esPredisenhado = false,
    this.ingredientes = const [],
  });

  /// Suma de los ítems del pedido.
  ///
  /// Antes esto era siempre `tamaño + frutas + extras`, lo que daba **0** en
  /// un pedido de prediseñado o de carrito: ninguno tiene tamaño, y el
  /// prediseñado tampoco tiene ingredientes sueltos. La factura mostraba
  /// entonces un total de solo el envío.
  ///
  /// Ahora manda `pedidos.total`, que es lo que de verdad se cobró. El
  /// desglose por ítems se sigue mostrando cuando existe, pero ya no es lo
  /// que define el importe.
  double get subtotal {
    if (totalGuardado > 0) return totalGuardado;
    // Respaldo para pedidos antiguos sin total utilizable.
    return tamanoPrice +
        frutas.fold(0.0, (s, f) => s + f.precio) +
        extras.fold(0.0, (s, e) => s + e.precio);
  }

  /// Total a pagar: subtotal de ítems + costo de envío.
  double get total => subtotal + costoEnvio;

  /// [costoEnvio] es solo el respaldo para pedidos que no traigan la
  /// columna. El valor real vive en `pedidos.costo_envio` (NOT NULL con
  /// DEFAULT 3000), así que si algún día cambia el costo del envío la
  /// factura lo refleja sola, sin tocar código.
  factory FacturaModel.fromSupabaseRow(Map<String, dynamic> row,
      {double costoEnvio = 3000}) {
    final id = row['id']?.toString() ?? '';
    final tamanoMap = row['tamanos_yogur'] as Map<String, dynamic>? ?? {};
    final saborMap = row['sabores'] as Map<String, dynamic>? ?? {};

    // Pedido de prediseñado: sin sabor ni tamaño propios (migración 0043).
    final predisenhadoMap =
        row['predisenhados'] as Map<String, dynamic>? ?? {};
    final nombrePredisenhado = predisenhadoMap['nombre'] as String? ?? '';
    final esPred = nombrePredisenhado.isNotEmpty;

    final ingredientes = (predisenhadoMap['ingredientes'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

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
      saborNombre:
          esPred ? nombrePredisenhado : (saborMap['nombre'] as String? ?? ''),
      frutas: frutas,
      extras: extras,
      totalGuardado: _parseDouble(row['total']),
      cantidad: (row['cantidad'] as num?)?.toInt() ?? 1,
      esPredisenhado: esPred,
      ingredientes: ingredientes,
      costoEnvio: row['costo_envio'] != null
          ? _parseDouble(row['costo_envio'])
          : costoEnvio,
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
