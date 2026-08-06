/// Modelo para la tabla `predisenhados` de Supabase.
/// Columnas reales (ver SUPABASE_SETUP.sql): id, nombre, descripcion,
///   ingredientes (JSONB, lista de strings), precio_total, imagen_url,
///   activo, es_popular, es_nuevo, created_at
class PredisenhadoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final List<String> ingredientes;
  final double precioTotal;
  final String? imagenUrl;
  final bool activo;
  final bool esPopular;
  final bool esNuevo;

  const PredisenhadoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.ingredientes = const [],
    required this.precioTotal,
    this.imagenUrl,
    this.activo = true,
    this.esPopular = false,
    this.esNuevo = false,
  });

  factory PredisenhadoModel.fromJson(Map<String, dynamic> json) {
    return PredisenhadoModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      ingredientes: _parseIngredientes(json['ingredientes']),
      precioTotal: _parseDouble(json['precio_total']),
      imagenUrl: json['imagen_url'] as String?,
      activo: json['activo'] as bool? ?? true,
      esPopular: json['es_popular'] as bool? ?? false,
      esNuevo: json['es_nuevo'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'ingredientes': ingredientes,
        'precio_total': precioTotal,
        if (imagenUrl != null) 'imagen_url': imagenUrl,
        'activo': activo,
        'es_popular': esPopular,
        'es_nuevo': esNuevo,
      };

  static List<String> _parseIngredientes(dynamic v) {
    if (v == null) return const [];
    if (v is List) {
      return v.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
