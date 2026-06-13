/// Modelo para la tabla `tamanos_yogur` de Supabase.
/// Columnas: id, nombre, precio
class TamanoModel {
  final String id;
  final String nombre;
  final double precioBase;

  const TamanoModel({
    required this.id,
    required this.nombre,
    required this.precioBase,
  });

  factory TamanoModel.fromJson(Map<String, dynamic> json) => TamanoModel(
        id: json['id']?.toString() ?? '',
        nombre: json['nombre'] as String? ?? '',
        precioBase: _parseDouble(json['precio']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'precio': precioBase,
      };

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
