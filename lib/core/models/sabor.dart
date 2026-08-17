/// Modelo que mapea la tabla `sabores` de Supabase.
class Sabor {
  final String id;
  final String nombre;
  final String descripcion;
  final double precioBase;
  final String? imagenUrl;
  /// Promedio de estrellas, o **null si nadie lo ha calificado todavía**.
  ///
  /// Antes esto era un `double` que caía en 5.0 cuando no había datos, así
  /// que todo producto recién creado aparecía con la nota máxima sin que
  /// nadie lo hubiera probado.
  final double? calificacionPromedio;
  final bool activo;
  final DateTime createdAt;

  const Sabor({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precioBase,
    this.imagenUrl,
    this.calificacionPromedio,
    required this.activo,
    required this.createdAt,
  });

  factory Sabor.fromJson(Map<String, dynamic> json) {
    return Sabor(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      precioBase: _parseDouble(json['precio_base']),
      imagenUrl: json['imagen_url'] as String?,
      calificacionPromedio: _parseDouble(json['calificacion_promedio']) > 0
          ? _parseDouble(json['calificacion_promedio'])
          : null,
      activo: json['activo'] as bool? ?? true,
      createdAt: _parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'precio_base': precioBase,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    if (calificacionPromedio != null)
      'calificacion_promedio': calificacionPromedio,
    'activo': activo,
    'created_at': createdAt.toIso8601String(),
  };

  /// Payload para INSERT (sin id ni created_at — los genera Supabase)
  Map<String, dynamic> toInsertJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'precio_base': precioBase,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'activo': true,
  };

  /// Payload para UPDATE (solo campos editables)
  Map<String, dynamic> toUpdateJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'precio_base': precioBase,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
  };

  Sabor copyWith({
    String? nombre,
    String? descripcion,
    double? precioBase,
    String? imagenUrl,
    double? calificacionPromedio,
    bool? activo,
  }) {
    return Sabor(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precioBase: precioBase ?? this.precioBase,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      calificacionPromedio: calificacionPromedio ?? this.calificacionPromedio,
      activo: activo ?? this.activo,
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
