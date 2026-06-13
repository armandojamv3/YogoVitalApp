/// Modelo que mapea la tabla `tamanos_yogur` de la base de datos.
///
/// SQL:
/// ```sql
/// CREATE TABLE public.tamanos_yogur (
///   id     UUID DEFAULT gen_random_uuid() PRIMARY KEY,
///   nombre TEXT NOT NULL UNIQUE,
///   precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0)
/// );
/// ```
class TamanoYogur {
  final String id;
  final String nombre;
  final double precio;

  const TamanoYogur({
    required this.id,
    required this.nombre,
    required this.precio,
  });

  factory TamanoYogur.fromJson(Map<String, dynamic> json) {
    return TamanoYogur(
      id: json['id']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      precio: _parseDouble(json['precio']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio': precio,
  };

  static double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}
