import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/models/pedido_historial.dart';
import 'package:yogo_vital_app/core/utils/id_format.dart';

/// Pedido enriquecido con datos del cliente para la vista admin.
class PedidoAdmin {
  final String id;
  final String estadoRaw;
  final double total;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String clienteId;
  final String clienteNombre;
  final String? clienteTelefono;
  final String tamanoNombre;
  final String saborNombre;
  final String dulzura;
  final String? direccionId;

  /// El pedido salió de un prediseñado: producto cerrado, sin tamaño ni
  /// sabor propios. Su contenido está en [ingredientes].
  final bool esPredisenhado;

  /// Receta del prediseñado. El admin la necesita para saber qué preparar:
  /// estos pedidos no generan filas en pedido_frutas ni pedido_extras.
  final List<String> ingredientes;

  const PedidoAdmin({
    required this.id,
    required this.estadoRaw,
    required this.total,
    required this.createdAt,
    required this.updatedAt,
    required this.clienteId,
    required this.clienteNombre,
    this.clienteTelefono,
    required this.tamanoNombre,
    required this.saborNombre,
    this.dulzura = 'Normal',
    this.direccionId,
    this.esPredisenhado = false,
    this.ingredientes = const [],
  });

  EstadoPedido get estado => EstadoPedidoExtension.fromString(estadoRaw);
  String get idCorto => '#${shortId(id)}';

  factory PedidoAdmin.fromRow(Map<String, dynamic> row) {
    final usuario = row['usuarios'] as Map<String, dynamic>? ?? {};
    final tamano = row['tamanos_yogur'] as Map<String, dynamic>? ?? {};
    final sabor = row['sabores'] as Map<String, dynamic>? ?? {};

    // Pedido de prediseñado: sabor_id y tamano_id quedan NULL (migración
    // 0043), así que el producto se identifica por el prediseñado. Sin
    // esto el admin veía el pedido sin nombre y no sabía qué preparar.
    final predisenhado = row['predisenhados'] as Map<String, dynamic>? ?? {};
    final nombrePredisenhado = predisenhado['nombre'] as String? ?? '';
    final esPred = nombrePredisenhado.isNotEmpty;

    final ingredientes = (predisenhado['ingredientes'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return PedidoAdmin(
      id: row['id']?.toString() ?? '',
      estadoRaw: row['estado'] as String? ?? 'Desconocido',
      total: _parseDouble(row['total']),
      createdAt: _parseDate(row['created_at']),
      updatedAt: _parseDate(row['updated_at']),
      clienteId: row['cliente_id']?.toString() ?? '',
      clienteNombre: usuario['nombre'] as String? ?? 'Sin nombre',
      clienteTelefono: usuario['telefono'] as String?,
      // Desde la 0045 un prediseñado también lleva tamaño. Vacío solo en
      // los pedidos anteriores a esa migración.
      tamanoNombre: tamano['nombre'] as String? ?? '',
      saborNombre:
          esPred ? nombrePredisenhado : (sabor['nombre'] as String? ?? ''),
      dulzura: row['dulzura'] as String? ?? 'Normal',
      esPredisenhado: esPred,
      ingredientes: ingredientes,
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

/// Pedido con detalle completo de ingredientes e historial (pantalla detalle).
class PedidoAdminDetalle extends PedidoAdmin {
  final double tamanoPrice;
  final List<IngredienteDetalle> frutas;
  final List<IngredienteDetalle> extras;
  final String? direccion;
  final String? direccionTelefono;
  final List<HistorialEstado> historial;

  const PedidoAdminDetalle({
    required super.id,
    required super.estadoRaw,
    required super.total,
    required super.createdAt,
    required super.updatedAt,
    required super.clienteId,
    required super.clienteNombre,
    super.clienteTelefono,
    required super.tamanoNombre,
    required super.saborNombre,
    super.dulzura,
    super.direccionId,
    super.esPredisenhado,
    super.ingredientes,
    this.tamanoPrice = 0,
    this.frutas = const [],
    this.extras = const [],
    this.direccion,
    this.direccionTelefono,
    this.historial = const [],
  });

  factory PedidoAdminDetalle.fromRow(Map<String, dynamic> row) {
    final base = PedidoAdmin.fromRow(row);
    final tamanoMap = row['tamanos_yogur'] as Map<String, dynamic>? ?? {};

    final frutas = (row['pedido_frutas'] as List? ?? [])
        .map((pf) {
          final f = pf['frutas'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: f['nombre'] as String? ?? '',
            precio: PedidoAdmin._parseDouble(f['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    final extras = (row['pedido_extras'] as List? ?? [])
        .map((pe) {
          final e = pe['extras'] as Map<String, dynamic>? ?? {};
          return IngredienteDetalle(
            nombre: e['nombre'] as String? ?? '',
            precio: PedidoAdmin._parseDouble(e['precio_adicional']),
          );
        })
        .where((i) => i.nombre.isNotEmpty)
        .toList();

    final historial = (row['historial_estados'] as List? ?? [])
        .map(HistorialEstado.fromRow)
        .toList()
      ..sort((a, b) => b.fechaCambio.compareTo(a.fechaCambio));

    final dirRow = row['direcciones'] as Map<String, dynamic>?;
    final direccionStr = dirRow != null
        ? '${dirRow['direccion'] ?? ''}, ${dirRow['barrio'] ?? ''}'
        : null;
    final direccionTelefono = dirRow?['telefono'] as String?;

    return PedidoAdminDetalle(
      id: base.id,
      estadoRaw: base.estadoRaw,
      total: base.total,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      clienteId: base.clienteId,
      clienteNombre: base.clienteNombre,
      clienteTelefono: base.clienteTelefono,
      tamanoNombre: base.tamanoNombre,
      saborNombre: base.saborNombre,
      dulzura: base.dulzura,
      direccionId: base.direccionId,
      esPredisenhado: base.esPredisenhado,
      ingredientes: base.ingredientes,
      tamanoPrice: PedidoAdmin._parseDouble(tamanoMap['precio']),
      frutas: frutas,
      extras: extras,
      direccion: direccionStr,
      direccionTelefono: direccionTelefono,
      historial: historial,
    );
  }
}

/// Un registro en `historial_estados`.
class HistorialEstado {
  final String id;
  final String? estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaCambio;
  final String? adminId;

  const HistorialEstado({
    required this.id,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.fechaCambio,
    this.adminId,
  });

  factory HistorialEstado.fromRow(dynamic row) {
    final m = row as Map<String, dynamic>;
    return HistorialEstado(
      id: m['id']?.toString() ?? '',
      estadoAnterior: m['estado_anterior'] as String?,
      estadoNuevo: m['estado_nuevo'] as String? ?? '',
      fechaCambio: PedidoAdmin._parseDate(m['fecha_cambio'] ?? m['created_at']),
      adminId: m['admin_id']?.toString(),
    );
  }
}
