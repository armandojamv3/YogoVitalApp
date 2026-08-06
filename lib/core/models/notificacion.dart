/// Notificación in-app (tabla `notificaciones`).
/// Sustituye al intento fallido de push notification vía FCM: no depende
/// de ningún servicio externo, solo de Supabase (tabla + Realtime).
class Notificacion {
  final String id;
  final String? pedidoId;
  final String? titulo;
  final String mensaje;
  final String? tipo;
  final bool leida;
  final DateTime createdAt;

  const Notificacion({
    required this.id,
    this.pedidoId,
    this.titulo,
    required this.mensaje,
    this.tipo,
    required this.leida,
    required this.createdAt,
  });

  // Esquema real en Supabase: usuario_id, titulo, mensaje, tipo, leida
  // (no "cliente_id"/"leido" como el resto del proyecto — esta tabla ya
  // existía de un sprint anterior con estos nombres).
  factory Notificacion.fromJson(Map<String, dynamic> json) {
    return Notificacion(
      id: json['id']?.toString() ?? '',
      pedidoId: json['pedido_id']?.toString(),
      titulo: json['titulo'] as String?,
      mensaje: json['mensaje'] as String? ?? '',
      tipo: json['tipo'] as String?,
      leida: json['leida'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
              DateTime.now(),
    );
  }
}
