/// Modelo que mapea la tabla `calificaciones` de la base de datos.
///
/// SQL:
/// ```sql
/// CREATE TABLE calificaciones (
///   id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   pedido_id  UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
///   cliente_id BIGINT NOT NULL REFERENCES users(id),
///   estrellas  SMALLINT NOT NULL CHECK (estrellas BETWEEN 1 AND 5),
///   comentario TEXT CHECK (char_length(comentario) <= 200),
///   created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
///   UNIQUE (pedido_id, cliente_id)
/// );
/// ```
class Calificacion {
  final String id;
  final String pedidoId;
  final String clienteId;
  final int estrellas;
  final String? comentario;
  final DateTime createdAt;

  const Calificacion({
    required this.id,
    required this.pedidoId,
    required this.clienteId,
    required this.estrellas,
    this.comentario,
    required this.createdAt,
  });

  factory Calificacion.fromJson(Map<String, dynamic> json) {
    return Calificacion(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedido_id']?.toString() ?? '',
      clienteId: json['cliente_id']?.toString() ?? '',
      estrellas: _parseInt(json['estrellas']),
      comentario: json['comentario'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pedido_id': pedidoId,
    'cliente_id': clienteId,
    'estrellas': estrellas,
    'comentario': comentario,
    'created_at': createdAt.toIso8601String(),
  };

  /// Payload para INSERT — cliente_id lo resuelve el backend
  Map<String, dynamic> toInsertJson() => {
    'pedido_id': pedidoId,
    'estrellas': estrellas,
    if (comentario != null && comentario!.isNotEmpty)
      'comentario': comentario,
  };

  static int _parseInt(dynamic v) {
    if (v == null) return 1;
    if (v is int) return v.clamp(1, 5);
    return int.tryParse(v.toString())?.clamp(1, 5) ?? 1;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
