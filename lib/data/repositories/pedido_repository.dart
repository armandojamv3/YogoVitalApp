import 'package:yogo_vital_app/core/models/pedido.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción personalizada para operaciones de pedidos
class PedidoException implements Exception {
  final String message;
  final int? statusCode;
  const PedidoException(this.message, {this.statusCode});

  @override
  String toString() => 'PedidoException($statusCode): $message';
}

/// Repositorio que gestiona operaciones sobre la tabla `pedidos` y `pedido_items`.
///
/// Utiliza [ApiClient] para peticiones HTTP al backend REST.
/// El stream de Realtime se simula con un [StreamController] que hace polling
/// cada [_pollInterval] segundos cuando no hay WebSocket nativo disponible.
class PedidoRepository {
  final ApiClient apiClient;

  /// Intervalo de polling para simular Realtime (ajustar según necesidad)
  static const _pollInterval = Duration(seconds: 10);

  PedidoRepository({required this.apiClient});

  // ─────────────────────────────────────────────────────────────────────────
  // 1. Obtener estado actual de un pedido  (HU_VerEstadoPedido_26)
  //    GET /pedidos/:id  → { estado, updated_at }
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtiene el [Pedido] completo dado su [pedidoId].
  ///
  /// Lanza [PedidoException] si el pedido no pertenece al usuario autenticado
  /// o si ocurre un error de red.
  Future<Pedido> obtenerEstadoPedido(String pedidoId) async {
    try {
      final data = await apiClient.get('/pedidos/$pedidoId');
      return Pedido.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo obtener el estado del pedido.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2. Stream Realtime para HU_VerEstadoPedido_26
  //    Emite el [Pedido] actualizado cada vez que cambia en la BD.
  //    Usa polling HTTP como fallback (sin Supabase Realtime WebSocket).
  // ─────────────────────────────────────────────────────────────────────────

  /// Devuelve un [Stream<Pedido>] que emite el pedido actualizado cada
  /// [_pollInterval]. El stream se cierra automáticamente al cancelar la
  /// suscripción desde la UI.
  ///
  /// Sustitúyelo por `supabase.from('pedidos').stream(...)` cuando
  /// integres el cliente Supabase directo.
  Stream<Pedido> streamEstadoPedido(String pedidoId) async* {
    while (true) {
      try {
        final pedido = await obtenerEstadoPedido(pedidoId);
        yield pedido;
      } catch (_) {
        // Si falla una iteración, seguir intentando en el siguiente ciclo
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3. Historial de pedidos del cliente autenticado  (HU_HistorialPedidos_28)
  //    GET /pedidos?sort=created_at.desc
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Pedido>> obtenerHistorial() async {
    try {
      final data = await apiClient.getDynamic('/pedidos');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Pedido.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw _mapError(e, 'No se pudo cargar el historial de pedidos.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4. Items de un pedido (para detalle / factura)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<PedidoItem>> obtenerItemsPedido(String pedidoId) async {
    try {
      final data = await apiClient.getDynamic('/pedidos/$pedidoId/items');
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(PedidoItem.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw _mapError(e, 'No se pudieron cargar los ítems del pedido.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 5. Cancelar pedido (HU_MultiplesDirecciones_25 / cancelación)
  //    PATCH /pedidos/:id/cancel  → 200 si estado era 'Recibido'
  // ─────────────────────────────────────────────────────────────────────────

  /// Intenta cancelar el pedido con [pedidoId].
  /// Lanza [PedidoException] con mensaje adecuado si ya está en proceso.
  Future<Pedido> cancelarPedido(String pedidoId) async {
    try {
      final data = await apiClient.patch(
        '/pedidos/$pedidoId/cancel',
        {'estado': 'Cancelado'},
      );
      return Pedido.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo cancelar el pedido.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────────────────────

  PedidoException _mapError(Object e, String fallback) {
    if (e is PedidoException) return e;
    final msg = e.toString();
    if (msg.contains('409') || msg.contains('already')) {
      return PedidoException(
        'Este pedido ya está en proceso y no puede ser cancelado.',
        statusCode: 409,
      );
    }
    if (msg.contains('404')) {
      return PedidoException('Pedido no encontrado.', statusCode: 404);
    }
    if (msg.contains('401') || msg.contains('403')) {
      return PedidoException(
        'No tienes permiso para ver este pedido.',
        statusCode: 403,
      );
    }
    return PedidoException(fallback);
  }
}
