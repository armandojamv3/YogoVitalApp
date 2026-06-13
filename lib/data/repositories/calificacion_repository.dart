import 'package:yogo_vital_app/core/models/calificacion.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción de dominio para operaciones sobre calificaciones.
class CalificacionException implements Exception {
  final String message;
  final int? statusCode;
  const CalificacionException(this.message, {this.statusCode});

  @override
  String toString() => 'CalificacionException($statusCode): $message';
}

/// Repositorio para la tabla `calificaciones` (HU_CalificarPedido_30).
///
/// Endpoints REST:
///   GET  `/calificaciones?pedido_id=:id` → Calificacion o null
///   POST `/calificaciones`               → Calificacion (cliente autenticado)
class CalificacionRepository {
  final ApiClient apiClient;

  CalificacionRepository({required this.apiClient});

  // ─────────────────────────────────────────────────────────────────────────
  // READ – obtener calificación de un pedido
  // ─────────────────────────────────────────────────────────────────────────

  /// Devuelve la [Calificacion] del [pedidoId] si existe, o null si aún
  /// no ha sido calificado.
  Future<Calificacion?> obtenerCalificacionPorPedido(String pedidoId) async {
    try {
      final data = await apiClient.getDynamic(
        '/calificaciones?pedido_id=$pedidoId',
      );
      if (data is List && data.isNotEmpty) {
        final first = data.whereType<Map<String, dynamic>>().firstOrNull;
        if (first != null) return Calificacion.fromJson(first);
      }
      if (data is Map<String, dynamic>) {
        return Calificacion.fromJson(data);
      }
      return null;
    } on CalificacionException {
      rethrow;
    } catch (_) {
      // Pedido sin calificación aún — devolvemos null
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE – HU_CalificarPedido_30
  // ─────────────────────────────────────────────────────────────────────────

  /// Envía la calificación del cliente para [pedidoId].
  /// Lanza [CalificacionException] si ya existe calificación o si hay error.
  Future<Calificacion> enviarCalificacion({
    required String pedidoId,
    required int estrellas,
    String? comentario,
  }) async {
    try {
      final payload = <String, dynamic>{
        'pedido_id': pedidoId,
        'estrellas': estrellas.clamp(1, 5),
        if (comentario != null && comentario.trim().isNotEmpty)
          'comentario': comentario.trim(),
      };
      final data = await apiClient.post('/calificaciones', payload);
      return Calificacion.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo guardar la calificación.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────────────────────

  CalificacionException _mapError(Object e, String fallback) {
    if (e is CalificacionException) return e;
    final msg = e.toString();
    if (msg.contains('409') || msg.contains('unique') || msg.contains('conflict')) {
      return const CalificacionException(
        'Ya calificaste este pedido.',
        statusCode: 409,
      );
    }
    if (msg.contains('403') || msg.contains('401')) {
      return const CalificacionException(
        'No tienes permiso para calificar este pedido.',
        statusCode: 403,
      );
    }
    if (msg.contains('404')) {
      return const CalificacionException(
        'Pedido no encontrado.',
        statusCode: 404,
      );
    }
    return CalificacionException(fallback);
  }
}
