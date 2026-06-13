/// Modelo para la tabla `predisenhados` de Supabase.
/// Columnas reales: id, nombre, descripcion, sabor_id, tamano_id,
///                  precio, imagen_url, activo, created_at
class PredisenhadoModel {
  final String id;
  final String nombre;
  final String descripcion;
  final String? saborId;
  final String? tamanoId;
  final double precio;
  final String? imagenUrl;
  final bool activo;

  const PredisenhadoModel({
    required this.id,
    required this.nombre,
    required this.descripcion,
    this.saborId,
    this.tamanoId,
    required this.precio,
    this.imagenUrl,
    this.activo = true,
  });

  factory PredisenhadoModel.fromJson(Map<String, dynamic> json) {
    return PredisenhadoModel(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      saborId: json['sabor_id'] as String?,
      tamanoId: json['tamano_id'] as String?,
      precio: _parseDouble(json['precio']),
      imagenUrl: json['imagen_url'] as String?,
      activo: json['activo'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        if (saborId != null) 'sabor_id': saborId,
        if (tamanoId != null) 'tamano_id': tamanoId,
        'precio': precio,
        if (imagenUrl != null) 'imagen_url': imagenUrl,
        'activo': activo,
      };

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
