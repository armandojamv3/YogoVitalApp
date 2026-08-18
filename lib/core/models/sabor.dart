/// Modelo que mapea la tabla `sabores` de Supabase.
class Sabor {
  final String id;
  final String nombre;
  final String descripcion;
  /// OBSOLETO desde la migración 0051. Ya no es lo que se cobra: el precio
  /// de un típico es el del tamaño más [recargo]. Se conserva porque hay
  /// pedidos antiguos calculados con él.
  final double? precioBase;

  /// Lo que suma este sabor al precio del tamaño.
  ///
  /// 0 significa sabor estándar, sin sobrecosto. Un chontaduro sale más
  /// caro que una piña porque la fruta cuesta más, y eso es lo que recoge
  /// este número.
  final double recargo;
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
    this.precioBase,
    this.recargo = 0,
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
      precioBase: json['precio_base'] == null
          ? null
          : _parseDouble(json['precio_base']),
      recargo: _parseDouble(json['recargo']),
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
    if (precioBase != null) 'precio_base': precioBase,
    'recargo': recargo,
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
    // `precio_base` ya no se escribe: es la columna obsoleta.
    'recargo': recargo,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
    'activo': true,
  };

  /// Payload para UPDATE (solo campos editables)
  Map<String, dynamic> toUpdateJson() => {
    'nombre': nombre,
    'descripcion': descripcion,
    'recargo': recargo,
    if (imagenUrl != null) 'imagen_url': imagenUrl,
  };

  Sabor copyWith({
    String? nombre,
    String? descripcion,
    double? precioBase,
    double? recargo,
    String? imagenUrl,
    double? calificacionPromedio,
    bool? activo,
  }) {
    return Sabor(
      id: id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precioBase: precioBase ?? this.precioBase,
      recargo: recargo ?? this.recargo,
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
