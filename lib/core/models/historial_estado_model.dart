class HistorialEstadoModel {
  final String id;
  final String pedidoId;
  final String? estadoAnterior;
  final String estadoNuevo;
  final DateTime fechaCambio;

  const HistorialEstadoModel({
    required this.id,
    required this.pedidoId,
    this.estadoAnterior,
    required this.estadoNuevo,
    required this.fechaCambio,
  });

  factory HistorialEstadoModel.fromJson(Map<String, dynamic> json) =>
      HistorialEstadoModel(
        id: json['id']?.toString() ?? '',
        pedidoId: json['pedido_id']?.toString() ?? '',
        estadoAnterior: json['estado_anterior'] as String?,
        estadoNuevo: json['estado_nuevo'] as String? ?? '',
        fechaCambio: _parse(json['fecha_cambio']),
      );

  static DateTime _parse(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ?? DateTime.now();
  }
}
