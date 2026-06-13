class DireccionModel {
  final String id;
  final String clienteId;
  final String direccion;
  final String barrio;
  final String telefono;
  final bool esPrincipal;
  final DateTime createdAt;

  const DireccionModel({
    required this.id,
    required this.clienteId,
    required this.direccion,
    required this.barrio,
    required this.telefono,
    this.esPrincipal = false,
    required this.createdAt,
  });

  factory DireccionModel.fromJson(Map<String, dynamic> json) => DireccionModel(
        id: json['id']?.toString() ?? '',
        clienteId: json['cliente_id']?.toString() ?? '',
        direccion: json['direccion'] as String? ?? '',
        barrio: json['barrio'] as String? ?? '',
        telefono: json['telefono'] as String? ?? '',
        esPrincipal: json['es_principal'] as bool? ?? false,
        createdAt: _parse(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cliente_id': clienteId,
        'direccion': direccion,
        'barrio': barrio,
        'telefono': telefono,
        'es_principal': esPrincipal,
      };

  String get etiqueta => '$direccion, $barrio';

  static DateTime _parse(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
