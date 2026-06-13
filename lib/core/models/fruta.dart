/// Modelo que mapea la tabla `frutas` de la base de datos.
///
/// SQL:
/// ```sql
/// CREATE TABLE frutas (
///   id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
///   nombre           TEXT NOT NULL,
///   precio_adicional NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (precio_adicional >= 0),
///   disponible       BOOLEAN NOT NULL DEFAULT TRUE,
///   imagen_url       TEXT,
///   created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
/// );
/// ```
class Fruta {
  final String id;
  final String nombre;
  final double precioAdicional;
  final bool disponible;
  final String? imagenUrl;
  final DateTime createdAt;

  const Fruta({
    required this.id,
    required this.nombre,
    required this.precioAdicional,
    required this.disponible,
    this.imagenUrl,
    required this.createdAt,
  });

  factory Fruta.fromJson(Map<String, dynamic> json) {
    return Fruta(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] as String? ?? '',
      precioAdicional: _parseDouble(json['precio_adicional']),
      disponible: json['disponible'] as bool? ?? true,
      imagenUrl: json['imagen_url'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio_adicional': precioAdicional,
    'disponible': disponible,
    'imagen_url': imagenUrl,
    'created_at': createdAt.toIso8601String(),
  };

  /// Payload para INSERT (Supabase genera id y created_at)
  Map<String, dynamic> toInsertJson() => {
    'nombre': nombre,
    'precio_adicional': precioAdicional,
    'disponible': true,
  };

  /// Payload para UPDATE (solo campos editables)
  Map<String, dynamic> toUpdateJson() => {
    'nombre': nombre,
    'precio_adicional': precioAdicional,
  };

  Fruta copyWith({
    String? nombre,
    double? precioAdicional,
    bool? disponible,
    String? imagenUrl,
  }) {
    return Fruta(
      id: id,
      nombre: nombre ?? this.nombre,
      precioAdicional: precioAdicional ?? this.precioAdicional,
      disponible: disponible ?? this.disponible,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      createdAt: createdAt,
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
