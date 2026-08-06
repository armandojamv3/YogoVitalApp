/// Promoción publicada por el admin (informativa — no aplica descuentos
/// automáticos al total del pedido).
class Promocion {
  final String id;
  final String titulo;
  final String descripcion;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool activa;
  final DateTime createdAt;

  const Promocion({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    this.fechaFin,
    required this.activa,
    required this.createdAt,
  });

  /// Vigente = marcada como activa por el admin Y dentro del rango de
  /// fechas (si tiene fecha de fin).
  bool get vigente {
    if (!activa) return false;
    final ahora = DateTime.now();
    if (ahora.isBefore(fechaInicio)) return false;
    if (fechaFin != null && ahora.isAfter(fechaFin!)) return false;
    return true;
  }

  factory Promocion.fromJson(Map<String, dynamic> json) {
    return Promocion(
      id: json['id']?.toString() ?? '',
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      fechaInicio: DateTime.tryParse(
              json['fecha_inicio']?.toString() ?? '') ??
          DateTime.now(),
      fechaFin: json['fecha_fin'] != null
          ? DateTime.tryParse(json['fecha_fin'].toString())
          : null,
      activa: json['activa'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'titulo': titulo,
    'descripcion': descripcion,
    'fecha_inicio': fechaInicio.toIso8601String(),
    if (fechaFin != null) 'fecha_fin': fechaFin!.toIso8601String(),
    'activa': activa,
  };
}
