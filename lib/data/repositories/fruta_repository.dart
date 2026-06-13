import 'package:yogo_vital_app/core/models/fruta.dart';
import 'package:yogo_vital_app/core/network/api_client.dart';

/// Excepción de dominio para operaciones sobre frutas.
class FrutaException implements Exception {
  final String message;
  final int? statusCode;
  const FrutaException(this.message, {this.statusCode});

  @override
  String toString() => 'FrutaException($statusCode): $message';
}

/// Repositorio CRUD para la tabla `frutas`.
///
/// Endpoints REST:
///   GET    `/frutas`       → List[Fruta]
///   POST   `/frutas`       → Fruta (admin)
///   PUT    `/frutas/:id`   → Fruta (admin)
///   PATCH  `/frutas/:id`   → Fruta (admin) – toggle disponibilidad / soft-delete
class FrutaRepository {
  final ApiClient apiClient;

  FrutaRepository({required this.apiClient});

  // ─────────────────────────────────────────────────────────────────────────
  // READ
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Fruta>> obtenerFrutas({bool soloDisponibles = false}) async {
    try {
      final path = soloDisponibles ? '/frutas?disponible=true' : '/frutas';
      final data = await apiClient.getDynamic(path);
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(Fruta.fromJson)
            .toList();
      }
      return [];
    } catch (e) {
      throw _mapError(e, 'No se pudo cargar la lista de frutas.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE – HU_GestionarFrutasExtras_35
  // ─────────────────────────────────────────────────────────────────────────

  Future<Fruta> agregarFruta({
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      final data = await apiClient.post('/frutas', {
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
        'disponible': true,
      });
      return Fruta.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo agregar la fruta.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UPDATE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Fruta> actualizarFruta({
    required String id,
    required String nombre,
    required double precioAdicional,
  }) async {
    try {
      final data = await apiClient.put('/frutas/$id', {
        'nombre': nombre.trim(),
        'precio_adicional': precioAdicional,
      });
      return Fruta.fromJson(data);
    } catch (e) {
      throw _mapError(e, 'No se pudo actualizar la fruta.');
    }
  }

  /// Toggle rápido de disponibilidad (HU_35)
  Future<void> toggleDisponibilidad(String id, {required bool disponible}) async {
    try {
      await apiClient.patch('/frutas/$id', {'disponible': disponible});
    } catch (e) {
      throw _mapError(e, 'No se pudo cambiar la disponibilidad.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOFT-DELETE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> eliminarFruta(String id) async {
    try {
      await apiClient.patch('/frutas/$id', {'disponible': false});
    } catch (e) {
      throw _mapError(e, 'No se pudo eliminar la fruta.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper
  // ─────────────────────────────────────────────────────────────────────────

  FrutaException _mapError(Object e, String fallback) {
    if (e is FrutaException) return e;
    final msg = e.toString();
    if (msg.contains('403') || msg.contains('401')) {
      return const FrutaException(
        'No tienes permiso para realizar esta acción.',
        statusCode: 403,
      );
    }
    if (msg.contains('409') || msg.contains('conflict')) {
      return const FrutaException(
        'Ya existe una fruta con ese nombre.',
        statusCode: 409,
      );
    }
    if (msg.contains('422') || msg.contains('validation')) {
      return const FrutaException(
        'Datos inválidos. Verifica los campos.',
        statusCode: 422,
      );
    }
    return FrutaException(fallback);
  }
}
