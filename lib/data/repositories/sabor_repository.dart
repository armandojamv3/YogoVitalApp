import 'package:yogo_vital_app/core/models/sabor.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción de dominio para operaciones sobre sabores.
class SaborException implements Exception {
  final String message;
  final int? statusCode;
  const SaborException(this.message, {this.statusCode});

  @override
  String toString() => 'SaborException($statusCode): $message';
}

/// Repositorio CRUD para la tabla `sabores`.
///
/// Todos los métodos de escritura son exclusivos del rol administrador
/// (validado en el backend / RLS de Supabase).
///
/// Endpoints REST asumidos:
///   GET    `/sabores`        → List[Sabor]
///   GET    `/sabores/:id`    → Sabor
///   POST   `/sabores`        → Sabor (admin)
///   PUT    `/sabores/:id`    → Sabor (admin)
///   PATCH  `/sabores/:id`    → Sabor (admin) – para soft-delete
class SaborRepository {
  final ApiClient apiClient;

  SaborRepository({required this.apiClient});

  // ──────────────────────────────────────────────────────────────
  // READ – lista completa de sabores activos
  // ──────────────────────────────────────────────────────────────

  Future<List<Sabor>> obtenerSabores({bool soloActivos = false}) async {
    try {
      final path = soloActivos ? '/sabores?activo=true' : '/sabores';
      final data = await apiClient.getDynamic(path);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Sabor.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw _mapError(e, 'No se pudo cargar la lista de sabores.');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // READ – un sabor por id
  // ──────────────────────────────────────────────────────────────

  Future<Sabor> obtenerSabor(String id) async {
    try {
      final data = await apiClient.getDynamic('/sabores/$id');
      return Sabor.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw _mapError(e, 'No se pudo cargar el sabor.');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // CREATE – HU_AgregarSabor_32
  // ──────────────────────────────────────────────────────────────

  /// Inserta un nuevo sabor.
  /// Lanza [SaborException] si hay error de validación o permisos.
  Future<Sabor> agregarSabor({
    required String nombre,
    required String descripcion,
    required double precioBase,
  }) async {
    try {
      final payload = {
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'precio_base': precioBase,
        'activo': true,
      };
      final data = await apiClient.post('/sabores', payload);
      return Sabor.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo agregar el sabor.');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // UPDATE – HU_EditarSabor_33
  // ──────────────────────────────────────────────────────────────

  Future<Sabor> actualizarSabor({
    required String id,
    required String nombre,
    required String descripcion,
    required double precioBase,
  }) async {
    try {
      final payload = {
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'precio_base': precioBase,
      };
      final data = await apiClient.put('/sabores/$id', payload);
      return Sabor.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo actualizar el sabor.');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SOFT-DELETE – HU_EliminarSabor_34
  // ──────────────────────────────────────────────────────────────

  /// Soft-delete: marca activo=false.
  /// El backend debe verificar pedidos activos antes de ejecutar.
  Future<void> eliminarSabor(String id) async {
    try {
      await apiClient.patch('/sabores/$id', {'activo': false});
    } catch (e) {
      throw _mapError(e, 'No se pudo eliminar el sabor.');
    }
  }

  /// Verifica si el sabor tiene pedidos activos (pre-validación cliente).
  Future<bool> tienePedidosActivos(String id) async {
    try {
      final data = await apiClient.getDynamic(
        '/sabores/$id/pedidos-activos',
      );
      if (data is Map<String, dynamic>) {
        return (data['count'] as int? ?? 0) > 0;
      }
      return false;
    } catch (_) {
      // Si el endpoint no existe, asumir false y dejar al backend validar
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Helper
  // ──────────────────────────────────────────────────────────────

  SaborException _mapError(Object e, String fallback) {
    if (e is SaborException) return e;
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('401')) {
      return const SaborException(
        'No tienes permiso para realizar esta acción.',
        statusCode: 403,
      );
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return const SaborException(
        'Ya existe un sabor con ese nombre.',
        statusCode: 409,
      );
    }
    if (msg.contains('422') || msg.contains('validation')) {
      return const SaborException(
        'Datos inválidos. Verifica los campos.',
        statusCode: 422,
      );
    }
    if (msg.contains('pedidos activos')) {
      return const SaborException(
        'No se puede eliminar: este sabor tiene pedidos activos.',
        statusCode: 400,
      );
    }
    return SaborException(fallback);
  }
}
